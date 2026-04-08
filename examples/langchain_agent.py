"""
PROXY + LangChain integration example.

pip install proxy-protocol langchain langchain-openai

OPENAI_API_KEY=sk-... PRIVATE_KEY=0x... python examples/langchain_agent.py
"""
from proxy_protocol import Proxy
from langchain.tools import Tool
from langchain.agents import initialize_agent, AgentType
from langchain_openai import ChatOpenAI

# Initialize PROXY SDK
proxy = Proxy(private_key="0x...", network="base-sepolia")


def hire_human(task_description: str) -> str:
    """Post a task for a human to complete in the physical world.
    Input should be a clear description of what needs to be done.
    Returns the task ID and status."""

    # Parse bounty from description or use default
    task = proxy.create(
        title=task_description[:100],
        description=task_description,
        bounty=10,  # default $10 USDC
        deadline="4h",
        proof_required=["photo"],
    )

    return f"Task #{task.id} created with $10 USDC bounty. A human will see this and complete it."


def check_task(task_id: str) -> str:
    """Check the status of a previously created task."""
    task = proxy.get_task(int(task_id))
    status_names = ["Open", "Accepted", "Submitted", "Completed", "Disputed", "Cancelled", "Expired"]
    status = status_names[task.status]

    if task.proof_uri:
        return f"Task #{task_id}: {status}. Proof: {task.proof_uri}"
    return f"Task #{task_id}: {status}"


# Create LangChain tools
tools = [
    Tool(
        name="hire_human",
        func=hire_human,
        description="Post a task for a human worker to complete in the physical world. "
                    "Use this when you need someone to do something that requires physical presence: "
                    "deliveries, inspections, photography, purchases, etc.",
    ),
    Tool(
        name="check_task",
        func=check_task,
        description="Check the status of a PROXY task by its ID number.",
    ),
]

# Initialize agent
llm = ChatOpenAI(model="gpt-4o", temperature=0)
agent = initialize_agent(
    tools,
    llm,
    agent=AgentType.OPENAI_FUNCTIONS,
    verbose=True,
)

# Run
if __name__ == "__main__":
    result = agent.run(
        "I need someone to go to the new ramen shop on Valencia St in SF "
        "and photograph their full menu. Budget $10."
    )
    print(result)
