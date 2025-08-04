defmodule VsmPhoenixWeb.AuthController do
  @moduledoc """
  Authentication controller for login, logout, token refresh, and user registration.
  """
  
  use VsmPhoenixWeb, :controller
  
  alias VsmPhoenix.Accounts
  alias VsmPhoenix.Auth.Guardian
  alias VsmPhoenixWeb.AuthPipeline
  
  action_fallback VsmPhoenixWeb.FallbackController
  
  @doc """
  User login endpoint.
  POST /api/auth/login
  """
  def login(conn, %{"email_or_username" => email_or_username, "password" => password} = params) do
    case Accounts.authenticate_user(email_or_username, password) do
      {:ok, user} ->
        handle_successful_login(conn, user, params)
        
      {:error, :invalid_credentials} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid credentials"})
        
      {:error, :account_inactive} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Account is inactive"})
        
      {:error, :account_locked} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Account is locked due to too many failed login attempts"})
    end
  end
  
  def login(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Email/username and password are required"})
  end
  
  @doc """
  Token refresh endpoint.
  POST /api/auth/refresh
  """
  def refresh(conn, %{"refresh_token" => refresh_token}) do
    case Guardian.refresh_tokens(refresh_token) do
      {:ok, tokens} ->
        conn
        |> json(%{
          access_token: tokens.access_token,
          refresh_token: tokens.refresh_token,
          expires_in: tokens.expires_in,
          token_type: "Bearer"
        })
        
      {:error, _reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid or expired refresh token"})
    end
  end
  
  def refresh(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Refresh token is required"})
  end
  
  @doc """
  User logout endpoint.
  POST /api/auth/logout
  """
  def logout(conn, _params) do
    token = Guardian.Plug.current_token(conn)
    
    case Guardian.revoke(token) do
      {:ok, _claims} ->
        conn
        |> json(%{message: "Successfully logged out"})
        
      {:error, _reason} ->
        # Even if revocation fails, we'll consider it a successful logout
        conn
        |> json(%{message: "Successfully logged out"})
    end
  end
  
  @doc """
  User registration endpoint.
  POST /api/auth/register
  """
  def register(conn, params) do
    # Only allow registration if enabled in config or if no admin users exist
    if registration_allowed?() do
      case Accounts.create_user(params) do
        {:ok, user} ->
          {:ok, tokens} = Guardian.create_tokens(user)
          
          conn
          |> put_status(:created)
          |> json(%{
            message: "User created successfully",
            user: user_response(user),
            access_token: tokens.access_token,
            refresh_token: tokens.refresh_token,
            expires_in: tokens.expires_in,
            token_type: "Bearer"
          })
          
        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "Registration failed", details: format_changeset_errors(changeset)})
      end
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "User registration is disabled"})
    end
  end
  
  @doc """
  Get current user information.
  GET /api/auth/me
  """
  def me(conn, _params) do
    user = AuthPipeline.get_current_user(conn)
    
    conn
    |> json(%{user: user_response(user)})
  end
  
  @doc """
  Change user password.
  POST /api/auth/change_password
  """
  def change_password(conn, %{"current_password" => current_password, "new_password" => new_password}) do
    user = AuthPipeline.get_current_user(conn)
    
    case Accounts.authenticate_user(user.email, current_password) do
      {:ok, _user} ->
        case Accounts.update_user_password(user, %{password: new_password}) do
          {:ok, _updated_user} ->
            # Revoke all existing tokens to force re-authentication
            Guardian.revoke_all_tokens_for_user(user)
            
            conn
            |> json(%{message: "Password changed successfully. Please log in again."})
            
          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Password change failed", details: format_changeset_errors(changeset)})
        end
        
      {:error, _reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Current password is incorrect"})
    end
  end
  
  def change_password(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Current password and new password are required"})
  end
  
  @doc """
  Request password reset.
  POST /api/auth/password_reset
  """
  def password_reset(conn, %{"email" => email}) do
    case Accounts.get_user_by_email(email) do
      nil ->
        # Don't reveal if email exists or not
        conn
        |> json(%{message: "If the email exists, a password reset link has been sent"})
        
      user ->
        {:ok, token, _claims} = Guardian.create_password_reset_token(user)
        
        # In a real application, you would send an email here
        # For demo purposes, we'll just return the token
        conn
        |> json(%{
          message: "Password reset token generated",
          reset_token: token,
          note: "In production, this would be sent via email"
        })
    end
  end
  
  @doc """
  Reset password with token.
  POST /api/auth/password_reset/confirm
  """
  def confirm_password_reset(conn, %{"reset_token" => reset_token, "new_password" => new_password}) do
    case Guardian.verify_token_type(reset_token, "password_reset") do
      {:ok, claims} ->
        case Guardian.resource_from_claims(claims) do
          {:ok, user} ->
            case Accounts.update_user_password(user, %{password: new_password}) do
              {:ok, _updated_user} ->
                # Revoke the reset token
                Guardian.revoke(reset_token)
                
                conn
                |> json(%{message: "Password reset successfully"})
                
              {:error, changeset} ->
                conn
                |> put_status(:unprocessable_entity)
                |> json(%{error: "Password reset failed", details: format_changeset_errors(changeset)})
            end
            
          {:error, _reason} ->
            conn
            |> put_status(:unauthorized)
            |> json(%{error: "Invalid reset token"})
        end
        
      {:error, _reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid or expired reset token"})
    end
  end
  
  @doc """
  Generate API key for current user.
  POST /api/auth/api_key
  """
  def generate_api_key(conn, params) do
    user = AuthPipeline.get_current_user(conn)
    
    case Accounts.generate_api_key(user, params) do
      {:ok, updated_user} ->
        conn
        |> json(%{
          message: "API key generated successfully",
          api_key: updated_user.api_key,
          expires_at: updated_user.api_key_expires_at
        })
        
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "API key generation failed", details: format_changeset_errors(changeset)})
    end
  end
  
  @doc """
  Revoke API key for current user.
  DELETE /api/auth/api_key
  """
  def revoke_api_key(conn, _params) do
    user = AuthPipeline.get_current_user(conn)
    
    case Accounts.revoke_api_key(user) do
      {:ok, _updated_user} ->
        conn
        |> json(%{message: "API key revoked successfully"})
        
      {:error, _reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to revoke API key"})
    end
  end
  
  @doc """
  Setup MFA (Multi-Factor Authentication).
  POST /api/auth/mfa/setup
  """
  def setup_mfa(conn, %{"mfa_secret" => mfa_secret, "backup_codes" => backup_codes}) do
    user = AuthPipeline.get_current_user(conn)
    
    attrs = %{
      mfa_enabled: true,
      mfa_secret: mfa_secret,
      backup_codes: backup_codes
    }
    
    case Accounts.setup_mfa(user, attrs) do
      {:ok, _updated_user} ->
        conn
        |> json(%{message: "MFA setup completed successfully"})
        
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "MFA setup failed", details: format_changeset_errors(changeset)})
    end
  end
  
  @doc """
  Disable MFA.
  DELETE /api/auth/mfa
  """
  def disable_mfa(conn, _params) do
    user = AuthPipeline.get_current_user(conn)
    
    case Accounts.disable_mfa(user) do
      {:ok, _updated_user} ->
        conn
        |> json(%{message: "MFA disabled successfully"})
        
      {:error, _reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to disable MFA"})
    end
  end
  
  # Private helper functions
  
  defp handle_successful_login(conn, user, params) do
    if user.mfa_enabled do
      # Create MFA token instead of full access token
      {:ok, mfa_token, _claims} = Guardian.create_mfa_token(user)
      
      conn
      |> json(%{
        message: "MFA verification required",
        mfa_token: mfa_token,
        mfa_required: true
      })
    else
      create_and_return_tokens(conn, user, params)
    end
  end
  
  defp create_and_return_tokens(conn, user, params) do
    {:ok, tokens} = Guardian.create_tokens(user)
    
    # Update last login information
    ip = get_client_ip(conn)
    Accounts.update_user(user, %{last_login_at: DateTime.utc_now(), last_login_ip: ip})
    
    response = %{
      access_token: tokens.access_token,
      refresh_token: tokens.refresh_token,
      expires_in: tokens.expires_in,
      token_type: "Bearer",
      user: user_response(user)
    }
    
    # Include remember_me functionality if requested
    response = if Map.get(params, "remember_me") do
      Map.put(response, :remember_me, true)
    else
      response
    end
    
    conn
    |> json(response)
  end
  
  defp user_response(user) do
    %{
      id: user.id,
      email: user.email,
      username: user.username,
      first_name: user.first_name,
      last_name: user.last_name,
      full_name: VsmPhoenix.Accounts.User.full_name(user),
      role: user.role,
      status: user.status,
      permissions: user.permissions || %{},
      mfa_enabled: user.mfa_enabled,
      last_login_at: user.last_login_at,
      force_password_change: user.force_password_change,
      inserted_at: user.inserted_at,
      updated_at: user.updated_at
    }
  end
  
  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
  
  defp registration_allowed? do
    # Allow registration if explicitly enabled in config
    # OR if no admin users exist (bootstrap scenario)
    Application.get_env(:vsm_phoenix, :allow_registration, false) or
      (VsmPhoenix.Accounts.get_user_stats().admins == 0)
  end
  
  defp get_client_ip(conn) do
    case Plug.Conn.get_req_header(conn, "x-forwarded-for") do
      [ip_list] ->
        ip_list
        |> String.split(",")
        |> List.first()
        |> String.trim()
        
      [] ->
        case Plug.Conn.get_req_header(conn, "x-real-ip") do
          [ip] -> ip
          [] -> conn.remote_ip |> :inet.ntoa() |> to_string()
        end
    end
  end
end