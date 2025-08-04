defmodule VsmPhoenix.Accounts.User do
  @moduledoc """
  User schema with comprehensive authentication and authorization features.
  Supports role-based access control, multi-factor authentication, and secure password hashing.
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :email, :string
    field :username, :string
    field :password, :string, virtual: true, redact: true
    field :password_hash, :string, redact: true
    field :first_name, :string
    field :last_name, :string
    field :role, Ecto.Enum, values: [:admin, :operator, :viewer, :agent], default: :viewer
    field :status, Ecto.Enum, values: [:active, :inactive, :suspended], default: :active
    
    # Multi-factor authentication
    field :mfa_enabled, :boolean, default: false
    field :mfa_secret, :string, redact: true
    field :backup_codes, {:array, :string}, default: [], redact: true
    
    # Security tracking
    field :last_login_at, :utc_datetime
    field :last_login_ip, :string
    field :failed_login_attempts, :integer, default: 0
    field :locked_until, :utc_datetime
    field :password_changed_at, :utc_datetime
    field :force_password_change, :boolean, default: false
    
    # API access
    field :api_key, :string, redact: true
    field :api_key_expires_at, :utc_datetime
    field :api_rate_limit, :integer, default: 1000  # requests per hour
    
    # Permissions (JSON field for flexible permissions)
    field :permissions, :map, default: %{}
    
    # Metadata
    field :metadata, :map, default: %{}
    
    timestamps(type: :utc_datetime)
  end
  
  @doc """
  Changeset for user registration
  """
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :username, :password, :first_name, :last_name, :role])
    |> validate_required([:email, :username, :password])
    |> validate_email()
    |> validate_username()
    |> validate_password()
    |> unique_constraint(:email)
    |> unique_constraint(:username)
    |> put_password_hash()
    |> put_password_changed_at()
  end
  
  @doc """
  Changeset for user updates
  """
  def update_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :username, :first_name, :last_name, :role, :status, :permissions, :metadata])
    |> validate_email()
    |> validate_username()
    |> unique_constraint(:email)
    |> unique_constraint(:username)
  end
  
  @doc """
  Changeset for password updates
  """
  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_password()
    |> put_password_hash()
    |> put_password_changed_at()
    |> put_change(:force_password_change, false)
    |> put_change(:failed_login_attempts, 0)
    |> put_change(:locked_until, nil)
  end
  
  @doc """
  Changeset for MFA setup
  """
  def mfa_changeset(user, attrs) do
    user
    |> cast(attrs, [:mfa_enabled, :mfa_secret, :backup_codes])
    |> validate_required_if_mfa_enabled()
  end
  
  @doc """
  Changeset for API key generation
  """
  def api_key_changeset(user, attrs \\ %{}) do
    user
    |> cast(attrs, [:api_rate_limit])
    |> put_api_key()
    |> put_api_key_expiration()
  end
  
  @doc """
  Changeset for tracking login attempts
  """
  def login_attempt_changeset(user, attrs) do
    user
    |> cast(attrs, [:last_login_at, :last_login_ip, :failed_login_attempts, :locked_until])
  end
  
  # Private functions
  
  defp validate_email(changeset) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, message: "must be a valid email address")
    |> validate_length(:email, max: 160)
  end
  
  defp validate_username(changeset) do
    changeset
    |> validate_required([:username])
    |> validate_format(:username, ~r/^[a-zA-Z0-9_-]+$/, message: "can only contain letters, numbers, hyphens and underscores")
    |> validate_length(:username, min: 3, max: 30)
  end
  
  defp validate_password(changeset) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    |> validate_format(:password, ~r/[a-z]/, message: "must contain at least one lowercase letter")
    |> validate_format(:password, ~r/[A-Z]/, message: "must contain at least one uppercase letter")
    |> validate_format(:password, ~r/[0-9]/, message: "must contain at least one number")
    |> validate_format(:password, ~r/[^a-zA-Z0-9]/, message: "must contain at least one special character")
  end
  
  defp validate_required_if_mfa_enabled(changeset) do
    case get_field(changeset, :mfa_enabled) do
      true ->
        changeset
        |> validate_required([:mfa_secret])
        |> validate_length(:backup_codes, min: 8, max: 10)
      _ ->
        changeset
    end
  end
  
  defp put_password_hash(%Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset) do
    changeset
    |> put_change(:password_hash, Argon2.hash_pwd_salt(password))
    |> delete_change(:password)
  end
  
  defp put_password_hash(changeset), do: changeset
  
  defp put_password_changed_at(changeset) do
    put_change(changeset, :password_changed_at, DateTime.utc_now())
  end
  
  defp put_api_key(changeset) do
    api_key = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
    put_change(changeset, :api_key, api_key)
  end
  
  defp put_api_key_expiration(changeset) do
    expires_at = DateTime.utc_now() |> DateTime.add(365, :day)  # 1 year expiration
    put_change(changeset, :api_key_expires_at, expires_at)
  end
  
  @doc """
  Verifies a password against the stored hash
  """
  def verify_password(user, password) do
    Argon2.verify_pass(password, user.password_hash)
  end
  
  @doc """
  Checks if user account is locked
  """
  def locked?(user) do
    case user.locked_until do
      nil -> false
      locked_until -> DateTime.compare(DateTime.utc_now(), locked_until) == :lt
    end
  end
  
  @doc """
  Checks if user has a specific permission
  """
  def has_permission?(user, permission) when is_binary(permission) do
    case user.permissions do
      %{^permission => true} -> true
      _ -> false
    end
  end
  
  @doc """
  Checks if user has any of the given roles
  """
  def has_role?(user, roles) when is_list(roles) do
    user.role in roles
  end
  
  def has_role?(user, role) when is_atom(role) do
    user.role == role
  end
  
  @doc """
  Checks if API key is valid and not expired
  """
  def valid_api_key?(user) do
    case user.api_key_expires_at do
      nil -> false
      expires_at -> DateTime.compare(DateTime.utc_now(), expires_at) == :lt
    end
  end
  
  @doc """
  Gets user's full name
  """
  def full_name(user) do
    case {user.first_name, user.last_name} do
      {nil, nil} -> user.username
      {first, nil} -> first
      {nil, last} -> last
      {first, last} -> "#{first} #{last}"
    end
  end
  
  @doc """
  Role hierarchy for authorization checks
  """
  def role_hierarchy do
    %{
      admin: 4,
      operator: 3,
      agent: 2,
      viewer: 1
    }
  end
  
  @doc """
  Checks if user role has sufficient level for required role
  """
  def role_sufficient?(user_role, required_role) do
    hierarchy = role_hierarchy()
    Map.get(hierarchy, user_role, 0) >= Map.get(hierarchy, required_role, 0)
  end
end