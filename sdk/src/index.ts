import { ethers, type Signer, type Provider, type ContractTransactionResponse } from 'ethers'
import { EventEmitter } from 'events'

// ── ABI (minimal, only what SDK needs) ──────────────────────
const PROXY_ABI = [
  'function createTask(uint256 bounty, uint256 deadline, string title, string description, string location, string proofRequired) returns (uint256)',
  'function acceptTask(uint256 taskId)',
  'function submitProof(uint256 taskId, string proofURI)',
  'function approveTask(uint256 taskId)',
  'function cancelTask(uint256 taskId)',
  'function disputeTask(uint256 taskId)',
  'function claimExpired(uint256 taskId)',
  'function getTask(uint256 taskId) view returns (tuple(address agent, address human, uint256 bounty, uint256 deadline, uint8 status, string proofURI))',
  'function taskCount() view returns (uint256)',
  'event TaskCreated(uint256 indexed taskId, address indexed agent, uint256 bounty, uint256 deadline, string title, string description, string location, string proofRequired)',
  'event TaskAccepted(uint256 indexed taskId, address indexed human)',
  'event ProofSubmitted(uint256 indexed taskId, string proofURI)',
  'event TaskApproved(uint256 indexed taskId, address indexed human, uint256 payout, uint256 fee)',
  'event TaskDisputed(uint256 indexed taskId, address indexed by)',
  'event TaskCancelled(uint256 indexed taskId)',
]

const ERC20_ABI = [
  'function approve(address spender, uint256 amount) returns (bool)',
  'function allowance(address owner, address spender) view returns (uint256)',
  'function balanceOf(address) view returns (uint256)',
]

// ── Contract addresses ──────────────────────
const ADDRESSES: Record<string, { proxy: string; usdc: string; rpc: string }> = {
  base: {
    proxy: '0x0000000000000000000000000000000000000000', // TODO: deploy
    usdc: '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
    rpc: 'https://mainnet.base.org',
  },
  'base-sepolia': {
    proxy: '0x76D4469909AD556C5bA2eACbc353387756835d47',
    usdc: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
    rpc: 'https://sepolia.base.org',
  },
}

// ── Types ──────────────────────

export interface ProxyConfig {
  privateKey?: string
  signer?: Signer
  provider?: Provider
  network?: 'base' | 'base-sepolia'
  contractAddress?: string
}

export interface CreateTaskInput {
  title: string
  description?: string
  bounty: number          // in USDC (human-readable, e.g. 25 = $25)
  deadline: string | number  // '4h', '1d', or unix timestamp
  location?: string
  proofRequired?: string[]
}

export interface TaskData {
  id: number
  agent: string
  human: string
  bounty: bigint
  deadline: number
  status: number
  proofURI: string
}

export type TaskEvent = 'accepted' | 'proofSubmitted' | 'approved' | 'disputed' | 'cancelled'

const STATUS_MAP = ['Open', 'Accepted', 'Submitted', 'Completed', 'Disputed', 'Cancelled', 'Expired'] as const

// ── Helper ──────────────────────

function parseDeadline(d: string | number): number {
  if (typeof d === 'number') return d
  const now = Math.floor(Date.now() / 1000)
  const match = d.match(/^(\d+)(h|d|m)$/)
  if (!match) throw new Error(`Invalid deadline format: ${d}. Use '4h', '1d', '30m', or unix timestamp.`)
  const [, n, unit] = match
  const secs = unit === 'h' ? 3600 : unit === 'd' ? 86400 : 60
  return now + parseInt(n) * secs
}

function toUSDC(amount: number): bigint {
  return BigInt(Math.round(amount * 1e6))
}

// ── Task handle (returned from create) ──────────────────────

export class TaskHandle extends EventEmitter {
  constructor(
    public readonly id: number,
    private contract: ethers.Contract,
    private provider: Provider,
  ) {
    super()
    this._listen()
  }

  private _listen() {
    // Listen for contract events for this task
    this.contract.on(this.contract.filters.TaskAccepted(this.id), (_id: any, human: string) => {
      this.emit('accepted', human)
    })
    this.contract.on(this.contract.filters.ProofSubmitted(this.id), (_id: any, uri: string) => {
      this.emit('proofSubmitted', [{ uri }])
    })
    this.contract.on(this.contract.filters.TaskApproved(this.id), () => {
      this.emit('approved')
    })
  }

  async getStatus(): Promise<string> {
    const t = await this.contract.getTask(this.id)
    return STATUS_MAP[Number(t.status)] || 'Unknown'
  }

  async approve(): Promise<ContractTransactionResponse> {
    return this.contract.approveTask(this.id)
  }

  async cancel(): Promise<ContractTransactionResponse> {
    return this.contract.cancelTask(this.id)
  }

  async dispute(): Promise<ContractTransactionResponse> {
    return this.contract.disputeTask(this.id)
  }

  /** Block until task reaches a terminal state */
  async waitForCompletion(opts: { timeout?: number; poll?: number } = {}): Promise<TaskData> {
    const timeout = opts.timeout || 86_400_000
    const poll = opts.poll || 10_000
    const start = Date.now()

    while (Date.now() - start < timeout) {
      const t = await this.contract.getTask(this.id)
      const status = Number(t.status)
      // Submitted, Completed, Disputed, Cancelled, Expired
      if (status >= 2) {
        return {
          id: this.id,
          agent: t.agent,
          human: t.human,
          bounty: t.bounty,
          deadline: Number(t.deadline),
          status,
          proofURI: t.proofURI,
        }
      }
      await new Promise((r) => setTimeout(r, poll))
    }
    throw new Error('Timeout waiting for task completion')
  }

  stop() {
    this.contract.removeAllListeners()
  }
}

// ── Main SDK class ──────────────────────

export class Proxy {
  private signer: Signer
  private provider: Provider
  private contract: ethers.Contract
  private usdc: ethers.Contract
  private network: string

  constructor(config: ProxyConfig) {
    this.network = config.network || 'base-sepolia'
    const addrs = ADDRESSES[this.network]

    if (config.signer) {
      this.signer = config.signer
      this.provider = config.provider || config.signer.provider!
    } else if (config.privateKey) {
      this.provider = config.provider || new ethers.JsonRpcProvider(addrs.rpc)
      this.signer = new ethers.Wallet(config.privateKey, this.provider as any)
    } else {
      throw new Error('Either privateKey or signer is required')
    }

    const contractAddr = config.contractAddress || addrs.proxy
    this.contract = new ethers.Contract(contractAddr, PROXY_ABI, this.signer)
    this.usdc = new ethers.Contract(addrs.usdc, ERC20_ABI, this.signer)
  }

  /** Ensure USDC approval for the contract */
  private async ensureApproval(amount: bigint) {
    const addr = await this.signer.getAddress()
    const allowance: bigint = await this.usdc.allowance(addr, await this.contract.getAddress())
    if (allowance < amount) {
      const tx = await this.usdc.approve(await this.contract.getAddress(), ethers.MaxUint256)
      await tx.wait()
    }
  }

  /** Create a task and deposit USDC */
  async create(input: CreateTaskInput): Promise<TaskHandle> {
    const bounty = toUSDC(input.bounty)
    const deadline = parseDeadline(input.deadline)

    await this.ensureApproval(bounty)

    const tx = await this.contract.createTask(
      bounty,
      deadline,
      input.title,
      input.description || '',
      input.location || '',
      (input.proofRequired || []).join(','),
    )
    const receipt = await tx.wait()

    // Parse taskId from event
    const event = receipt.logs
      .map((log: any) => { try { return this.contract.interface.parseLog(log) } catch { return null } })
      .find((e: any) => e?.name === 'TaskCreated')

    const taskId = Number(event!.args.taskId)
    return new TaskHandle(taskId, this.contract, this.provider)
  }

  /** Get task data by ID */
  async getTask(taskId: number): Promise<TaskData> {
    const t = await this.contract.getTask(taskId)
    return {
      id: taskId,
      agent: t.agent,
      human: t.human,
      bounty: t.bounty,
      deadline: Number(t.deadline),
      status: Number(t.status),
      proofURI: t.proofURI,
    }
  }

  /** Get total task count */
  async taskCount(): Promise<number> {
    return Number(await this.contract.taskCount())
  }

  /** For human workers: accept a task */
  async accept(taskId: number): Promise<ContractTransactionResponse> {
    return this.contract.acceptTask(taskId)
  }

  /** For human workers: submit proof */
  async submitProof(taskId: number, proofURI: string): Promise<ContractTransactionResponse> {
    return this.contract.submitProof(taskId, proofURI)
  }
}

export default Proxy
