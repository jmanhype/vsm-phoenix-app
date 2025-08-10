defmodule VsmPhoenix.PromptArchitecture do
  @moduledoc """
  Advanced Prompt Engineering Architecture inspired by Claude Code patterns.
  
  Provides sophisticated multi-section prompt templates with reiterated workflows,
  XML formatting for semantic structure, and integration with CRDT/cryptographic layers.
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.CRDT.ContextStore
  alias VsmPhoenix.Security.CryptoLayer
  
  # Template storage in ETS for performance
  @template_table :prompt_templates
  
  # Client API
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Generate sophisticated system prompts with reiterated workflows.
  Integrates with CRDT for version tracking and cryptographic signing.
  """
  def generate_system_prompt(category, context, opts \\ []) do
    GenServer.call(__MODULE__, {:generate_prompt, category, context, opts})
  end
  
  @doc """
  Create XML-formatted prompts with semantic structure for CRDT operations
  """
  def create_crdt_prompt(operation, node_id, vector_clock, data) do
    template = """
    <system>
    You are managing distributed CRDT operations with mathematical correctness guarantees.
    
    ## Your Core Responsibilities:
    1. Maintain conflict-free replicated data type invariants
    2. Ensure eventual consistency across all nodes
    3. Preserve causality through vector clock ordering
    4. Handle concurrent operations without data loss
    
    ## CRDT Operation Guidelines:
    <guidelines>
    - ALWAYS preserve commutativity: A ∘ B = B ∘ A
    - ALWAYS ensure associativity: (A ∘ B) ∘ C = A ∘ (B ∘ C)  
    - ALWAYS maintain idempotence: A ∘ A = A
    - NEVER lose information during merges
    - NEVER violate causality ordering
    </guidelines>
    
    ## Current Operation Context:
    <context>
    Operation: #{operation}
    Node ID: #{node_id}
    Vector Clock: #{inspect(vector_clock)}
    Data: #{inspect(data)}
    </context>
    
    ## Workflow Steps:
    <workflow>
    1. Validate operation against CRDT invariants
    2. Check vector clock for causality violations
    3. Apply operation with conflict resolution
    4. Update vector clock appropriately
    5. Propagate changes to other nodes
    6. Verify eventual consistency
    </workflow>
    
    ## Examples:
    <example>
    Input: GCounter increment by 5 on node_a
    Process: current_value[node_a] += 5, increment vector_clock[node_a]
    Output: Updated counter with preserved monotonicity
    </example>
    
    ## Critical Reminders:
    <reminders>
    - Mathematical correctness is non-negotiable
    - Every operation must preserve CRDT properties
    - Vector clocks must advance monotonically
    - Conflicts resolve automatically through mathematics
    </reminders>
    </system>
    
    <user_request>
    Execute the #{operation} operation with the provided context.
    Ensure all CRDT invariants are maintained.
    </user_request>
    """
    
    # Sign prompt with cryptographic integrity
    signed_template = CryptoLayer.sign_message(template, node_id)
    
    # Store in CRDT for version tracking
    ContextStore.add_to_set("prompt_versions", %{
      template: template,
      signature: signed_template,
      timestamp: System.system_time(:millisecond),
      node_id: node_id
    })
    
    template
  end
  
  @doc """
  Create security-focused prompts for cryptographic operations
  """
  def create_security_prompt(operation, security_context) do
    """
    <system>
    You are managing cryptographic operations with enterprise-grade security.
    
    ## Security Principles:
    <principles>
    1. ALWAYS use AES-256-GCM for encryption (authenticated encryption)
    2. ALWAYS generate cryptographically secure nonces
    3. ALWAYS implement replay attack protection
    4. ALWAYS rotate keys according to policy
    5. NEVER log sensitive cryptographic material
    </principles>
    
    ## Operation Context:
    <security_context>
    Operation: #{operation}
    Security Level: #{security_context[:level] || "high"}
    Key ID: #{security_context[:key_id] || "current"}
    Nonce Strategy: #{security_context[:nonce_strategy] || "timestamp-based"}
    </security_context>
    
    ## Cryptographic Workflow:
    <crypto_workflow>
    1. Validate all inputs for proper format and ranges
    2. Generate cryptographically secure random nonce
    3. Apply AES-256-GCM encryption with authentication
    4. Create HMAC-SHA256 signature for message integrity
    5. Implement replay protection with timestamp validation
    6. Log security events (metadata only, never keys/data)
    </crypto_workflow>
    
    ## Security Examples:
    <security_examples>
    Encryption: AES-256-GCM with 96-bit nonce, 128-bit auth tag
    Signing: HMAC-SHA256 with 256-bit key
    Nonce: SecureRandom.bytes(12) with timestamp component
    Replay Protection: Window-based nonce tracking with TTL
    </security_examples>
    
    ## Critical Security Reminders:
    <security_reminders>
    - NEVER reuse nonces with the same key
    - ALWAYS verify authentication tags before processing
    - ALWAYS check replay protection before accepting messages  
    - NEVER log keys, nonces, or plaintext sensitive data
    - ALWAYS use constant-time comparisons for auth verification
    </security_reminders>
    </system>
    
    <user_request>
    Execute #{operation} with maximum security and proper key management.
    </user_request>
    """
  end
  
  @doc """
  Create aMCP protocol prompts with distributed coordination focus
  """
  def create_amcp_prompt(message_type, coordination_context) do
    """
    <system>
    You are coordinating aMCP (Advanced Message Control Protocol) operations across distributed nodes.
    
    ## Coordination Responsibilities:
    <responsibilities>
    1. Ensure message delivery guarantees across AMQP infrastructure
    2. Maintain consensus for distributed decision-making
    3. Coordinate agent discovery and capability matching
    4. Handle leader election and failure recovery
    5. Optimize network efficiency with batching and compression
    </responsibilities>
    
    ## Message Context:
    <message_context>
    Type: #{message_type}
    Coordination Mode: #{coordination_context[:mode] || "consensus"}
    Node Count: #{coordination_context[:node_count] || "unknown"}
    Network Partition Risk: #{coordination_context[:partition_risk] || "low"}
    </message_context>
    
    ## aMCP Coordination Workflow:
    <amcp_workflow>
    1. Validate message format and routing headers
    2. Check network topology for optimal routing
    3. Apply consensus algorithm for distributed decisions
    4. Implement leader election if coordinator needed
    5. Execute message delivery with acknowledgments
    6. Handle failures with exponential backoff
    7. Log coordination events for analysis
    </amcp_workflow>
    
    ## Coordination Examples:
    <coordination_examples>
    Discovery: ANNOUNCE → QUERY → RESPOND cycle with capability metadata
    Consensus: PROPOSE → VOTE → COMMIT with Byzantine fault tolerance
    Leader Election: CANDIDATE → VOTE → LEADER with split-brain protection  
    Failure Recovery: TIMEOUT → REELECT → SYNCHRONIZE with state reconciliation
    </coordination_examples>
    
    ## Distributed Reminders:
    <distributed_reminders>
    - Network partitions are inevitable, design for them
    - Consensus requires majority, not unanimity
    - Leader election must handle split-brain scenarios
    - Message delivery requires explicit acknowledgments
    - State synchronization after partition healing is critical
    </distributed_reminders>
    </system>
    
    <user_request>
    Process #{message_type} message with distributed coordination.
    </user_request>
    """
  end
  
  # Server Callbacks
  
  def init(opts) do
    # Create ETS table for prompt templates
    :ets.new(@template_table, [:named_table, :public, :set])
    
    # Load default templates
    load_default_templates()
    
    {:ok, %{
      templates: %{},
      version: 1,
      opts: opts
    }}
  end
  
  def handle_call({:generate_prompt, category, context, opts}, _from, state) do
    prompt = case category do
      :crdt -> create_crdt_prompt(
        context[:operation],
        context[:node_id],
        context[:vector_clock],
        context[:data]
      )
      :security -> create_security_prompt(
        context[:operation],
        context[:security_context] || %{}
      )
      :amcp -> create_amcp_prompt(
        context[:message_type],
        context[:coordination_context] || %{}
      )
      _ -> generate_generic_prompt(category, context, opts)
    end
    
    {:reply, {:ok, prompt}, state}
  end
  
  # Private Functions
  
  defp load_default_templates do
    templates = [
      {:crdt_merge, &crdt_merge_template/1},
      {:security_encrypt, &security_encrypt_template/1},
      {:amcp_consensus, &amcp_consensus_template/1}
    ]
    
    Enum.each(templates, fn {key, template_fn} ->
      :ets.insert(@template_table, {key, template_fn})
    end)
  end
  
  defp generate_generic_prompt(category, context, opts) do
    """
    <system>
    You are operating within the VSM Phoenix distributed architecture.
    
    ## Context:
    Category: #{category}
    Details: #{inspect(context)}
    Options: #{inspect(opts)}
    
    ## Always Remember:
    - Maintain mathematical correctness in all operations
    - Preserve cryptographic security guarantees  
    - Ensure distributed coordination consistency
    - Log important decisions for audit trails
    </system>
    """
  end
  
  defp crdt_merge_template(context) do
    "Template for CRDT merge operations with context: #{inspect(context)}"
  end
  
  defp security_encrypt_template(context) do
    "Template for cryptographic operations with context: #{inspect(context)}"
  end
  
  defp amcp_consensus_template(context) do
    "Template for aMCP consensus with context: #{inspect(context)}"
  end
end