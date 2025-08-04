defmodule VsmPhoenix.Accounts do
  @moduledoc """
  The Accounts context.
  Provides functions for user management, authentication, and authorization.
  """
  
  import Ecto.Query, warn: false
  alias VsmPhoenix.Repo
  alias VsmPhoenix.Accounts.User
  
  @doc """
  Returns the list of users.
  """
  def list_users do
    Repo.all(User)
  end
  
  @doc """
  Returns the list of users with pagination.
  """
  def list_users(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 25)
    role_filter = Keyword.get(opts, :role)
    status_filter = Keyword.get(opts, :status)
    search = Keyword.get(opts, :search)
    
    query = from(u in User)
    
    query =
      if role_filter do
        where(query, [u], u.role == ^role_filter)
      else
        query
      end
    
    query =
      if status_filter do
        where(query, [u], u.status == ^status_filter)
      else
        query
      end
    
    query =
      if search do
        search_term = "%#{search}%"
        where(query, [u], 
          ilike(u.email, ^search_term) or 
          ilike(u.username, ^search_term) or 
          ilike(u.first_name, ^search_term) or 
          ilike(u.last_name, ^search_term)
        )
      else
        query
      end
    
    query
    |> order_by([u], desc: u.inserted_at)
    |> limit(^per_page)
    |> offset(^((page - 1) * per_page))
    |> Repo.all()
  end
  
  @doc """
  Gets a single user.
  """
  def get_user!(id), do: Repo.get!(User, id)
  
  @doc """
  Gets a user by email.
  """
  def get_user_by_email(email) do
    Repo.get_by(User, email: email)
  end
  
  @doc """
  Gets a user by username.
  """
  def get_user_by_username(username) do
    Repo.get_by(User, username: username)
  end
  
  @doc """
  Gets a user by API key.
  """
  def get_user_by_api_key(api_key) do
    case Repo.get_by(User, api_key: api_key) do
      nil -> nil
      user -> 
        if User.valid_api_key?(user) do
          user
        else
          nil
        end
    end
  end
  
  @doc """
  Gets a user by email or username for login.
  """
  def get_user_by_email_or_username(email_or_username) do
    query = from(u in User, 
      where: u.email == ^email_or_username or u.username == ^email_or_username
    )
    Repo.one(query)
  end
  
  @doc """
  Creates a user.
  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end
  
  @doc """
  Updates a user.
  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.update_changeset(attrs)
    |> Repo.update()
  end
  
  @doc """
  Updates user password.
  """
  def update_user_password(%User{} = user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> Repo.update()
  end
  
  @doc """
  Deletes a user.
  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end
  
  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.
  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.update_changeset(user, attrs)
  end
  
  @doc """
  Authenticates a user with email/username and password.
  """
  def authenticate_user(email_or_username, password) do
    case get_user_by_email_or_username(email_or_username) do
      nil ->
        # Prevent timing attacks
        Argon2.no_user_verify()
        {:error, :invalid_credentials}
      
      user ->
        if user.status != :active do
          {:error, :account_inactive}
        else
          if User.locked?(user) do
            {:error, :account_locked}
          else
            if User.verify_password(user, password) do
              # Reset failed attempts on successful login
              update_login_success(user)
              {:ok, user}
            else
              update_failed_login(user)
              {:error, :invalid_credentials}
            end
          end
        end
    end
  end
  
  @doc """
  Authenticates a user with API key.
  """
  def authenticate_api_key(api_key) do
    case get_user_by_api_key(api_key) do
      nil -> {:error, :invalid_api_key}
      user -> 
        if user.status == :active do
          {:ok, user}
        else
          {:error, :account_inactive}
        end
    end
  end
  
  @doc """
  Generates a new API key for a user.
  """
  def generate_api_key(%User{} = user, attrs \\ %{}) do
    user
    |> User.api_key_changeset(attrs)
    |> Repo.update()
  end
  
  @doc """
  Revokes a user's API key.
  """
  def revoke_api_key(%User{} = user) do
    user
    |> change_user(%{api_key: nil, api_key_expires_at: nil})
    |> Repo.update()
  end
  
  @doc """
  Sets up MFA for a user.
  """
  def setup_mfa(%User{} = user, attrs) do
    user
    |> User.mfa_changeset(attrs)
    |> Repo.update()
  end
  
  @doc """
  Disables MFA for a user.
  """
  def disable_mfa(%User{} = user) do
    user
    |> User.mfa_changeset(%{mfa_enabled: false, mfa_secret: nil, backup_codes: []})
    |> Repo.update()
  end
  
  @doc """
  Locks a user account for security reasons.
  """
  def lock_user(%User{} = user, duration_hours \\ 24) do
    locked_until = DateTime.utc_now() |> DateTime.add(duration_hours, :hour)
    
    user
    |> User.login_attempt_changeset(%{locked_until: locked_until})
    |> Repo.update()
  end
  
  @doc """
  Unlocks a user account.
  """
  def unlock_user(%User{} = user) do
    user
    |> User.login_attempt_changeset(%{
      locked_until: nil, 
      failed_login_attempts: 0
    })
    |> Repo.update()
  end
  
  @doc """
  Forces a password change for a user.
  """
  def force_password_change(%User{} = user) do
    user
    |> change_user(%{force_password_change: true})
    |> Repo.update()
  end
  
  @doc """
  Updates user's role.
  """
  def update_user_role(%User{} = user, role) when role in [:admin, :operator, :viewer, :agent] do
    user
    |> change_user(%{role: role})
    |> Repo.update()
  end
  
  @doc """
  Updates user's status.
  """
  def update_user_status(%User{} = user, status) when status in [:active, :inactive, :suspended] do
    user
    |> change_user(%{status: status})
    |> Repo.update()
  end
  
  @doc """
  Updates user permissions.
  """
  def update_user_permissions(%User{} = user, permissions) when is_map(permissions) do
    current_permissions = user.permissions || %{}
    new_permissions = Map.merge(current_permissions, permissions)
    
    user
    |> change_user(%{permissions: new_permissions})
    |> Repo.update()
  end
  
  @doc """
  Grants a permission to a user.
  """
  def grant_permission(%User{} = user, permission) when is_binary(permission) do
    update_user_permissions(user, %{permission => true})
  end
  
  @doc """
  Revokes a permission from a user.
  """
  def revoke_permission(%User{} = user, permission) when is_binary(permission) do
    current_permissions = user.permissions || %{}
    new_permissions = Map.delete(current_permissions, permission)
    
    user
    |> change_user(%{permissions: new_permissions})
    |> Repo.update()
  end
  
  @doc """
  Gets user statistics.
  """
  def get_user_stats do
    total_users = from(u in User) |> Repo.aggregate(:count)
    active_users = from(u in User, where: u.status == :active) |> Repo.aggregate(:count)
    admin_users = from(u in User, where: u.role == :admin) |> Repo.aggregate(:count)
    locked_users = from(u in User, where: not is_nil(u.locked_until)) |> Repo.aggregate(:count)
    
    %{
      total: total_users,
      active: active_users,
      admins: admin_users,
      locked: locked_users
    }
  end
  
  @doc """
  Creates the default admin user if none exists.
  """
  def ensure_admin_user do
    case from(u in User, where: u.role == :admin) |> Repo.one() do
      nil ->
        # Create default admin user
        attrs = %{
          email: "admin@vsm-system.local",
          username: "admin",
          password: generate_secure_password(),
          first_name: "System",
          last_name: "Administrator",
          role: :admin,
          status: :active,
          permissions: %{
            "system:full_access" => true,
            "users:manage" => true,
            "vsm:admin" => true
          }
        }
        
        case create_user(attrs) do
          {:ok, user} ->
            IO.puts("Default admin user created:")
            IO.puts("Email: #{user.email}")
            IO.puts("Username: #{user.username}")
            IO.puts("Password: #{attrs.password}")
            IO.puts("Please change the password immediately after first login!")
            {:ok, user}
          error ->
            error
        end
        
      admin_user ->
        {:ok, admin_user}
    end
  end
  
  # Private functions
  
  defp update_login_success(user) do
    attrs = %{
      last_login_at: DateTime.utc_now(),
      failed_login_attempts: 0,
      locked_until: nil
    }
    
    user
    |> User.login_attempt_changeset(attrs)
    |> Repo.update()
  end
  
  defp update_failed_login(user) do
    failed_attempts = (user.failed_login_attempts || 0) + 1
    
    attrs = %{failed_login_attempts: failed_attempts}
    
    # Lock account after 5 failed attempts
    attrs = if failed_attempts >= 5 do
      locked_until = DateTime.utc_now() |> DateTime.add(24, :hour)
      Map.put(attrs, :locked_until, locked_until)
    else
      attrs
    end
    
    user
    |> User.login_attempt_changeset(attrs)
    |> Repo.update()
  end
  
  defp generate_secure_password do
    # Generate a random secure password
    :crypto.strong_rand_bytes(16)
    |> Base.encode64()
    |> String.slice(0, 16)
    |> then(&"Admin#{&1}!")
  end
end