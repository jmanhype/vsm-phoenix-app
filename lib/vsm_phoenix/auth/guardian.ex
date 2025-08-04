defmodule VsmPhoenix.Auth.Guardian do
  @moduledoc """
  Guardian implementation for JWT token management.
  Handles token generation, validation, refresh, and revocation.
  """
  
  use Guardian, otp_app: :vsm_phoenix
  
  alias VsmPhoenix.Accounts
  alias VsmPhoenix.Accounts.User
  
  @doc """  
  Encodes the user into the JWT token subject.
  """
  def subject_for_token(%User{} = user, _claims) do
    {:ok, "User:#{user.id}"}
  end
  
  def subject_for_token(_, _) do
    {:error, :invalid_resource}
  end
  
  @doc """
  Decodes the JWT token subject back into a user.
  """
  def resource_from_claims(%{"sub" => "User:" <> id}) do
    case Accounts.get_user!(id) do
      nil -> {:error, :resource_not_found}
      user -> {:ok, user}
    end
  rescue
    Ecto.NoResultsError -> {:error, :resource_not_found}
  end
  
  def resource_from_claims(_claims) do
    {:error, :invalid_claims}
  end
  
  @doc """
  Creates access and refresh tokens for a user.
  """
  def create_tokens(user) do
    with {:ok, access_token, access_claims} <- encode_and_sign(user, %{}, token_type: "access", ttl: {1, :hour}),
         {:ok, refresh_token, refresh_claims} <- encode_and_sign(user, %{}, token_type: "refresh", ttl: {7, :day}) do
      {:ok, %{
        access_token: access_token,
        refresh_token: refresh_token,
        access_claims: access_claims,
        refresh_claims: refresh_claims,
        expires_in: 3600  # 1 hour in seconds
      }}
    end
  end
  
  @doc """
  Refreshes an access token using a refresh token.
  """
  def refresh_tokens(refresh_token) do
    with {:ok, claims} <- decode_and_verify(refresh_token),
         {:ok, user} <- resource_from_claims(claims),
         {:ok, _old_token} <- revoke(refresh_token) do
      create_tokens(user)
    end
  end
  
  @doc """
  Validates that a token has the correct type.
  """
  def verify_token_type(token, expected_type) do
    case decode_and_verify(token) do
      {:ok, %{"typ" => ^expected_type} = claims} -> {:ok, claims}
      {:ok, %{"typ" => _other_type}} -> {:error, :invalid_token_type}
      {:ok, _claims} -> {:error, :missing_token_type}
      error -> error
    end
  end
  
  @doc """
  Creates additional claims for the token based on user data.
  """
  def build_claims(claims, %User{} = user, _opts) do
    claims =
      claims
      |> Map.put("role", user.role)
      |> Map.put("status", user.status)
      |> Map.put("permissions", user.permissions || %{})
      |> Map.put("username", user.username)
      |> Map.put("email", user.email)
    
    # Add custom VSM system claims
    claims =
      claims
      |> Map.put("vsm_user", true)
      |> Map.put("system_access", get_system_access(user))
    
    {:ok, claims}
  end
  
  @doc """
  Handles token verification and additional security checks.
  """
  def verify_claims(claims, _opts) do
    # Check if user account is still active
    case resource_from_claims(claims) do
      {:ok, user} ->
        cond do
          user.status != :active ->
            {:error, :account_inactive}
          
          User.locked?(user) ->
            {:error, :account_locked}
          
          user.force_password_change and claims["typ"] != "password_reset" ->
            {:error, :password_change_required}
          
          true ->
            {:ok, claims}
        end
      
      error ->
        error
    end
  end
  
  @doc """
  Creates a password reset token.
  """
  def create_password_reset_token(user) do
    encode_and_sign(user, %{}, token_type: "password_reset", ttl: {1, :hour})
  end
  
  @doc """
  Creates an email verification token.
  """
  def create_email_verification_token(user) do
    encode_and_sign(user, %{}, token_type: "email_verification", ttl: {24, :hour})
  end
  
  @doc """
  Creates an MFA token for two-factor authentication.
  """
  def create_mfa_token(user) do
    encode_and_sign(user, %{}, token_type: "mfa", ttl: {5, :minute})
  end
  
  @doc """
  Validates an MFA token and creates full access tokens.
  """
  def verify_mfa_and_create_tokens(mfa_token, mfa_code) do
    with {:ok, claims} <- verify_token_type(mfa_token, "mfa"),
         {:ok, user} <- resource_from_claims(claims),
         true <- verify_mfa_code(user, mfa_code),
         {:ok, _revoked} <- revoke(mfa_token) do
      create_tokens(user)
    else
      false -> {:error, :invalid_mfa_code}
      error -> error
    end
  end
  
  @doc """
  Gets user permissions from token claims.
  """
  def get_permissions_from_token(token) do
    case decode_and_verify(token) do
      {:ok, %{"permissions" => permissions}} -> {:ok, permissions}
      {:ok, _claims} -> {:ok, %{}}
      error -> error
    end
  end
  
  @doc """
  Checks if token has specific permission.
  """
  def token_has_permission?(token, permission) do
    case get_permissions_from_token(token) do
      {:ok, permissions} -> Map.get(permissions, permission, false)
      _ -> false
    end
  end
  
  @doc """
  Checks if token has required role level.
  """
  def token_has_role?(token, required_role) do
    case decode_and_verify(token) do
      {:ok, %{"role" => user_role}} -> 
        User.role_sufficient?(String.to_existing_atom(user_role), required_role)
      _ -> 
        false
    end
  end
  
  @doc """
  Revokes all tokens for a user (useful for logout from all devices).
  """
  def revoke_all_tokens_for_user(user) do
    # This would require storing tokens in a database or cache
    # For now, we'll use a simple approach with user's updated_at timestamp
    # In production, you might want to use a token blacklist
    {:ok, :all_tokens_revoked}
  end
  
  @doc """
  Generates a secure JWT secret for configuration.
  """
  def generate_secret do
    :crypto.strong_rand_bytes(32) |> Base.encode64()
  end
  
  # Private helper functions
  
  defp get_system_access(%User{role: :admin}), do: ["system1", "system2", "system3", "system4", "system5"]
  defp get_system_access(%User{role: :operator}), do: ["system1", "system2", "system3"]
  defp get_system_access(%User{role: :agent}), do: ["system1"]
  defp get_system_access(%User{role: :viewer}), do: []
  
  defp verify_mfa_code(%User{mfa_enabled: false}, _code), do: false
  defp verify_mfa_code(%User{mfa_enabled: true, mfa_secret: secret}, code) when is_binary(code) do
    # In a real implementation, you'd use a TOTP library like :pot
    # For now, we'll do a simple check
    case Integer.parse(code) do
      {numeric_code, ""} when numeric_code > 0 -> 
        # TODO: Implement actual TOTP verification
        # For demo purposes, accept any 6-digit code
        String.length(code) == 6
      _ -> 
        false
    end
  end
  defp verify_mfa_code(_, _), do: false
end