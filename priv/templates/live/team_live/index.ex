defmodule __MODULE_PREFIX__Web.TeamLive.Index do
  @moduledoc """
  LiveView for managing team members and pending invitations in a workspace.
  This LiveView allows users to view current members, search for members,
  invite new members, and manage pending invitations.
  """

  use __MODULE_PREFIX__Web, :live_view
  alias __MODULE_PREFIX__.Accounts
  import __MODULE_PREFIX__Web.TeamLive.Components
  on_mount {__MODULE_PREFIX__Web.AshWorkspaceLiveUserAuth, :live_user_required}

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_page={@current_page}>
      <div class="bg-base-200/50 min-h-screen p-4 sm:p-6 lg:p-8">
        <div class="max-w-4xl mx-auto space-y-8">
          <.page_header />
          <.active_members_card
            filtered_members={@filtered_members}
            member_query={@member_query}
            current_user={@current_user}
          />
          <.pending_invitations_card pending_invitations={@pending_invitations} />
        </div>
      </div>

      <.invite_member_modal
        show_invite_modal={@show_invite_modal}
        invite_form={@invite_form}
        invite_errors={@invite_errors}
      />

      <.confirmation_modal
        show={@show_remove_member_modal}
        id="remove_member_modal"
        title="Remove Team Member"
        message={
          "Are you sure you want to remove #{@remove_member_email} from this workspace? Their access will be immediately revoked."
        }
        confirm_text="Confirm Removal"
        confirm_action="confirm_remove_member"
      />
      <.confirmation_modal
        show={@show_revoke_invite_modal}
        id="revoke_invite_modal"
        title="Revoke Invitation"
        message={
          "Are you sure you want to revoke the invitation for #{@revoke_invite_email}?"
        }
        confirm_text="Confirm Revoke"
        confirm_action="confirm_revoke_invite"
      />
    </Layouts.app>
    """
  end

  def mount(%{"workspace_id" => workspace_id}, _session, socket) do
    {:ok,
     socket
     |> setup_page_defaults(workspace_id)}
  end

  def handle_event("search_member", %{"member_query" => query}, socket) do
    filtered_members =
      if query == "" do
        socket.assigns.members
      else
        socket.assigns.members
        |> Enum.filter(fn user ->
          String.contains?(String.downcase(to_string(user.email)), String.downcase(query))
        end)
      end

    {:noreply, assign(socket, filtered_members: filtered_members, member_query: query)}
  end

  def handle_event("open_invite_modal", _params, socket) do
    {:noreply, assign(socket, show_invite_modal: true)}
  end

  def handle_event(
        "open_remove_member_modal",
        %{"id" => id, "email" => email},
        socket
      ) do
    {:noreply,
     assign(socket,
       show_remove_member_modal: true,
       remove_member_id: id,
       remove_member_email: email
     )}
  end

  def handle_event("open_revoke_invite_modal", %{"id" => id, "email" => email}, socket) do
    {:noreply,
     assign(socket,
       show_revoke_invite_modal: true,
       revoke_invite_id: id,
       revoke_invite_email: email
     )}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply,
     assign(socket,
       show_invite_modal: false,
       show_remove_member_modal: false,
       remove_member_id: nil,
       remove_member_email: nil,
       show_revoke_invite_modal: false,
       revoke_invite_id: nil,
       revoke_invite_email: nil,
       invite_form: %{"email" => "", "role" => "member"},
       invite_errors: %{}
     )}
  end

  def handle_event("confirm_remove_member", _params, socket) do
    id = socket.assigns.remove_member_id
    workspace_id = socket.assigns.current_workspace_id

    case Accounts.delete_workspace_user(id, actor: socket.assigns.current_user) do
      :ok ->
        {:noreply,
         put_flash(socket, :info, "Member removed successfully.") |> setup_page_defaults(workspace_id)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Member not found.")}
    end
  end

  def handle_event("update_invite_form", %{"invite" => invite_params}, socket) do
    {:noreply,
     assign(socket,
       invite_form: invite_params,
       invite_errors: %{},
       show_invite_modal: true
     )}
  end

  def handle_event("submit_invite", %{"invite" => %{"email" => email, "role" => role}}, socket) do
    user = socket.assigns.current_user
    workspace_id = socket.assigns.current_workspace_id

    case __MODULE_PREFIX__.Accounts.create_invitation(email, String.to_atom(role), workspace_id, user.id, actor: user) do
      {:ok, _invitation} ->
        {:noreply,
         socket
         |> assign(
           invite_form: %{"email" => "", "role" => "member"},
           invite_errors: %{},
           show_invite_modal: false
         )
         |> put_flash(:info, "Invitation sent!")
         |> setup_page_defaults(workspace_id)}

      {:error, %Ash.Error.Invalid{errors: errors}} ->
        parsed_errors =
          for %Ash.Error.Changes.InvalidAttribute{field: field, message: msg} <- errors,
              into: %{} do
            {field, msg}
          end

        {:noreply, assign(socket, invite_errors: parsed_errors, show_invite_modal: true)}

      {:error, _other} ->
        {:noreply,
         assign(socket, invite_errors: %{email: "Something went wrong."}, show_invite_modal: true)}
    end
  end

  def handle_event("resend_invite", %{"id" => id}, socket) do
    workspace_id = socket.assigns.current_workspace_id

    case __MODULE_PREFIX__.Accounts.resend_invitation(id, actor: socket.assigns.current_user) do
      {:ok, _} ->
        {:noreply, put_flash(socket, :info, "Invitation resent.") |> setup_page_defaults(workspace_id)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to resend invitation.")}
    end
  end

  def handle_event("confirm_revoke_invite", _params, socket) do
    id = socket.assigns.revoke_invite_id
    workspace_id = socket.assigns.current_workspace_id

    case __MODULE_PREFIX__.Accounts.revoke_invitation(id, actor: socket.assigns.current_user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Invitation revoked.")
         |> assign(show_revoke_invite_modal: false)
         |> setup_page_defaults(workspace_id)}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to revoke invitation.")
         |> assign(show_revoke_invite_modal: false)}
    end
  end

  defp setup_page_defaults(socket, workspace_id) do
    members = setup_members(workspace_id, socket.assigns.current_user)
    invitations = setup_pending_invitations(workspace_id)

    assign(socket,
      page_title: "Team",
      current_user: socket.assigns.current_user,
      current_page: "team",
      invite_form: %{"email" => "", "role" => "member"},
      invite_errors: %{},
      show_invite_modal: false,
      show_remove_member_modal: false,
      remove_member_id: nil,
      remove_member_email: nil,
      show_revoke_invite_modal: false,
      revoke_invite_id: nil,
      revoke_invite_email: nil,
      members: members,
      filtered_members: members,
      member_query: "",
      current_workspace_id: workspace_id,
      pending_invitations: invitations
    )
  end

  defp setup_members(workspace_id, actor) do
    case __MODULE_PREFIX__.Accounts.get_workspace_users_by_workspace_id(workspace_id, actor: actor) do
      {:ok, workspace_users} ->
        workspace_users
        |> Enum.map(fn workspace_user ->
          case Ash.load(workspace_user, :user, actor: actor) do
            {:ok, loaded} when not is_nil(loaded.user) ->
              loaded.user
              |> Map.put(:workspace_role, loaded.role)
              |> Map.put(:workspace_user_id, loaded.id)

            _ ->
              nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      {:error, _} ->
        []
    end
  end

  defp setup_pending_invitations(workspace_id) do
    case __MODULE_PREFIX__.Accounts.list_all_pending_invitations(actor: socket.assigns.current_user) do
      {:ok, invitations} ->
        Enum.filter(invitations, fn inv -> to_string(inv.workspace_id) == workspace_id end)

      {:error, _} ->
        []
    end
  end
end
