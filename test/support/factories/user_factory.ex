defmodule VsmPhoenix.UserFactory do
  @moduledoc """
  Factory for creating test users with various roles and configurations.
  """
  
  alias VsmPhoenix.Accounts.User
  
  def build(:user) do
    %User{
      id: Ecto.UUID.generate(),
      email: "user#{System.unique_integer([:positive])}@example.com",
      username: "testuser#{System.unique_integer([:positive])}",
      password_hash: Bcrypt.hash_pwd_salt("password123"),
      first_name: "Test",
      last_name: "User",
      role: :user,
      status: :active,
      permissions: %{},
      failed_login_attempts: 0,
      force_password_change: false,
      mfa_enabled: false,
      backup_codes: [],
      inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
      updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }
  end
  
  def build(:admin) do
    build(:user)
    |> Map.put(:role, :admin)
    |> Map.put(:email, "admin#{System.unique_integer([:positive])}@example.com")
    |> Map.put(:username, "admin#{System.unique_integer([:positive])}")
    |> Map.put(:permissions, %{
      "users" => ["read", "write", "delete"],
      "systems" => ["read", "write", "control"],
      "chaos" => ["read", "write", "execute"],
      "quantum" => ["read", "write", "execute"],
      "meta_vsm" => ["read", "write", "spawn"]
    })
  end
  
  def build(:operator) do
    build(:user)
    |> Map.put(:role, :operator)
    |> Map.put(:email, "operator#{System.unique_integer([:positive])}@example.com")
    |> Map.put(:username, "operator#{System.unique_integer([:positive])}")
    |> Map.put(:permissions, %{
      "systems" => ["read", "control"],
      "monitoring" => ["read", "write"]
    })
  end
  
  def build(:agent) do
    build(:user)
    |> Map.put(:role, :agent)
    |> Map.put(:email, "agent#{System.unique_integer([:positive])}@example.com")
    |> Map.put(:username, "agent#{System.unique_integer([:positive])}")
    |> Map.put(:permissions, %{
      "operations" => ["read", "execute"]
    })
  end
  
  def build(:viewer) do
    build(:user)
    |> Map.put(:role, :viewer)
    |> Map.put(:email, "viewer#{System.unique_integer([:positive])}@example.com")
    |> Map.put(:username, "viewer#{System.unique_integer([:positive])}")
    |> Map.put(:permissions, %{
      "systems" => ["read"],
      "monitoring" => ["read"]
    })
  end
  
  def build(:locked_user) do
    build(:user)
    |> Map.put(:status, :locked)
    |> Map.put(:failed_login_attempts, 5)
    |> Map.put(:locked_at, DateTime.utc_now() |> DateTime.truncate(:second))
  end
  
  def build(:inactive_user) do
    build(:user)
    |> Map.put(:status, :inactive)
  end
  
  def build(:mfa_user) do
    build(:user)
    |> Map.put(:mfa_enabled, true)
    |> Map.put(:mfa_secret, "JBSWY3DPEHPK3PXP")
    |> Map.put(:backup_codes, ["12345678", "87654321", "11111111"])
  end
  
  def build(:api_key_user) do
    api_key = "ak_" <> (:crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower))
    
    build(:user)
    |> Map.put(:api_key, api_key)
    |> Map.put(:api_key_expires_at, DateTime.utc_now() |> DateTime.add(365, :day) |> DateTime.truncate(:second))
  end
  
  def build(:expired_api_key_user) do
    api_key = "ak_" <> (:crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower))
    
    build(:user)
    |> Map.put(:api_key, api_key)
    |> Map.put(:api_key_expires_at, DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.truncate(:second))
  end
  
  def build(factory_name, attributes) do
    factory_name |> build() |> struct!(attributes)
  end
  
  def insert!(factory_name, attributes \\ []) do
    factory_name
    |> build(attributes)
    |> VsmPhoenix.Repo.insert!()
  end
  
  # Helper functions for tests
  
  def valid_user_attributes(overrides \\ %{}) do
    %{
      email: "test#{System.unique_integer([:positive])}@example.com",
      username: "testuser#{System.unique_integer([:positive])}",
      password: "SecurePassword123!",
      first_name: "Test",
      last_name: "User",
      role: :user
    }
    |> Map.merge(overrides)
  end
  
  def invalid_user_attributes do
    %{
      email: "invalid-email",
      username: "",
      password: "weak",
      first_name: "",
      last_name: "",
      role: :invalid_role
    }
  end
  
  def create_user_with_api_key do
    user = insert!(:api_key_user)
    api_key = user.api_key
    {user, api_key}
  end
  
  def create_admin_user do
    insert!(:admin)
  end
  
  def create_locked_user do
    insert!(:locked_user)
  end
  
  def create_mfa_user do
    insert!(:mfa_user)
  end
end