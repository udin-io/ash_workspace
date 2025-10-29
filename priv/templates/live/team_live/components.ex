defmodule __MODULE_PREFIX__Web.TeamLive.Components do
  @moduledoc """
  UI components for the Team Members LiveView, using core components.
  """
  use __MODULE_PREFIX__Web, :live_component

  # Import AshWorkspace-specific components (card, badge, avatar, modals, etc.)
  import __MODULE_PREFIX__Web.AshWorkspace.CoreComponents

  ## Header

  def page_header(assigns) do
    ~H"""
    <div class="flex flex-col sm:flex-row justify-between items-start">
      <div>
        <h1 class="text-3xl font-bold text-base-content">Team Members</h1>
        <p class="mt-1 text-base-content/70">
          Manage who has access to this workspace and what they can do.
        </p>
      </div>
      <div class="mt-4 sm:mt-0">
        <.button variant="primary" icon="hero-user-plus" phx-click="open_invite_modal">
          Invite Member
        </.button>
      </div>
    </div>
    """
  end

  ## Active Members

  def active_members_card(assigns) do
    ~H"""
    <.card title="Active Members">
      <:header>
        <.member_search_form member_query={@member_query} />
      </:header>
      <.members_table filtered_members={@filtered_members} current_user={@current_user} />
    </.card>
    """
  end

  def member_search_form(assigns) do
    ~H"""
    <.search_input
      name="member_query"
      value={@member_query}
      placeholder="Search members by email..."
      size="sm"
      phx-change="search_member"
    />
    """
  end

  def members_table(assigns) do
    ~H"""
    <.table id="members" rows={@filtered_members}>
      <:col :let={member} label="Member">
        <div class="flex items-center gap-3">
          <.avatar email={member.email} size="base" />
          <p class="text-sm opacity-70">{member.email}</p>
        </div>
      </:col>
      <:col :let={member} label="Role">
        {human_role(member.workspace_role)}
      </:col>
      <:action :let={member}>
        <.button
          :if={@current_user.id != member.id}
          size="xs"
          class="text-error"
          phx-click="open_remove_member_modal"
          phx-value-id={member.workspace_user_id}
          phx-value-email={member.email}
        >
          Remove
        </.button>
        <.badge :if={@current_user.id == member.id} size="sm" variant="neutral">
          You
        </.badge>
      </:action>
    </.table>
    """
  end

  ## Invitations

  def pending_invitations_card(assigns) do
    ~H"""
    <.card title="Pending Invitations">
      <.invitations_table pending_invitations={@pending_invitations} />
    </.card>
    """
  end

  def invitations_table(assigns) do
    ~H"""
    <.table id="invitations" rows={@pending_invitations}>
      <:col :let={invite} label="Email">
        {invite.email}
      </:col>
      <:col :let={invite} label="Role">
        <.badge size="sm">{human_role(invite.role)}</.badge>
      </:col>
      <:col :let={invite} label="Invited">
        {invitation_time_ago(invite.updated_at)}
      </:col>
      <:action :let={invite}>
        <.button
          size="xs"
          phx-click="resend_invite"
          phx-value-id={invite.id}
        >
          Resend
        </.button>
        <.button
          size="xs"
          class="text-error"
          phx-click="open_revoke_invite_modal"
          phx-value-id={invite.id}
          phx-value-email={invite.email}
        >
          Revoke
        </.button>
      </:action>
    </.table>
    """
  end

  ## Invite Modal

  def invite_member_modal(assigns) do
    ~H"""
    <.form_modal
      show={@show_invite_modal}
      id="invite-modal"
      title="Invite New Member"
      form_id="invite-form"
      submit_text="Send Invite"
      cancel_text="Cancel"
      phx_submit="submit_invite"
      phx_change="update_invite_form"
    >
      <div class="form-control w-full">
        <label for="invite_email" class="label-text">Email Address</label>
        <input
          id="invite_email"
          name="invite[email]"
          type="email"
          value={@invite_form["email"] || ""}
          placeholder="Enter email address"
          class="input input-bordered w-full"
          oninput="this.value = this.value.toLowerCase()"
          required
        />
        <%= if @invite_errors[:email] do %>
          <p class="text-error text-sm mt-1">{@invite_errors[:email]}</p>
        <% end %>
      </div>

      <div class="form-control w-full mt-4">
        <label for="invite_role" class="label-text">Role</label>
        <select id="invite_role" name="invite[role]" class="select select-bordered">
          <option value="member" selected={@invite_form["role"] == "member"}>Member</option>
          <option value="admin" selected={@invite_form["role"] == "admin"}>Admin</option>
          <option value="billing" selected={@invite_form["role"] == "billing"}>Billing</option>
        </select>
      </div>
    </.form_modal>
    """
  end

  ## Confirmation Modal

  def confirmation_modal(assigns) do
    ~H"""
    <.confirm_modal
      show={@show}
      id={@id}
      title={@title}
      message={@message}
      confirm_action={@confirm_action}
      confirm_text={@confirm_text}
    />
    """
  end

  ## Helpers

  defp human_role(role), do: role |> to_string() |> Phoenix.Naming.humanize()

  defp invitation_time_ago(updated_at) do
    case DateTime.diff(DateTime.utc_now(), updated_at, :day) do
      0 -> "Today"
      days -> "#{days} day#{if days != 1, do: "s", else: ""} ago"
    end
  end
end
