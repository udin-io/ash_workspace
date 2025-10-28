defmodule __MODULE_PREFIX__Web.AshWorkspace.CoreComponents do
  @moduledoc """
  Provides core UI components required by AshWorkspace team management features.

  This module contains components that may not exist in a standard Phoenix application:
  - card
  - search_input
  - badge
  - avatar
  - confirm_modal
  - form_modal

  These components use daisyUI classes and are designed to work seamlessly with
  Phoenix LiveView and the AshWorkspace team management features.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  @doc """
  Renders a card component.

  ## Examples

      <.card title="My Card">
        Content goes here
      </.card>

      <.card size="lg" class="my-custom-class">
        <:header>
          <button>Action</button>
        </:header>
        Card content
      </.card>
  """
  attr :title, :string, default: nil
  attr :size, :string, default: "base", values: ~w(sm base lg xl)
  attr :class, :string, default: ""
  attr :rest, :global
  slot :header, doc: "Optional header slot for action buttons"
  slot :inner_block, required: true

  def card(assigns) do
    ~H"""
    <div
      class={[
        "card bg-base-100",
        size_classes("card", @size),
        @class
      ]}
      {@rest}
    >
      <div class="card-body">
        <div
          :if={@title || @header != []}
          class={[
            "flex items-center mb-4",
            if(@header != [], do: "justify-between", else: "justify-start")
          ]}
        >
          <h2 :if={@title} class="card-title">{@title}</h2>
          <div :if={@header != []} class="flex items-center gap-2">
            {render_slot(@header)}
          </div>
        </div>
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  @doc """
  Renders a search input component.

  ## Examples

      <.search_input placeholder="Search members..." phx-change="search" />
      <.search_input name="query" value={@query} size="sm" />
  """
  attr :name, :string, default: "query"
  attr :value, :string, default: ""
  attr :placeholder, :string, default: "Search..."
  attr :size, :string, default: "base", values: ~w(xs sm base lg)
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(phx-change phx-submit form)

  def search_input(assigns) do
    ~H"""
    <.form for={%{}} as={:search} {@rest} class={["w-full max-w-xs", @class]}>
      <input
        type="text"
        name={@name}
        placeholder={@placeholder}
        class={[
          "input input-bordered w-full",
          size_classes("input", @size)
        ]}
        value={@value}
      />
    </.form>
    """
  end

  @doc """
  Renders a badge component.

  ## Examples

      <.badge>New</.badge>
      <.badge variant="success" size="sm">Active</.badge>
  """
  attr :variant, :string,
    default: "neutral",
    values: ~w(neutral primary secondary accent ghost info success warning error)

  attr :size, :string, default: "base", values: ~w(xs sm base lg)
  attr :class, :string, default: ""
  attr :rest, :global

  slot :inner_block, required: true

  def badge(assigns) do
    ~H"""
    <span
      class={[
        "badge",
        variant_classes("badge", @variant),
        size_classes("badge", @size),
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </span>
    """
  end

  @doc """
  Renders an avatar component.

  ## Examples

      <.avatar src="/images/avatar.jpg" alt="User" />
      <.avatar email="user@example.com" size="lg" />
  """
  attr :src, :string, default: nil
  attr :alt, :string, default: "Avatar"
  attr :email, :string, default: nil
  attr :size, :string, default: "base", values: ~w(xs sm base lg xl)
  attr :shape, :string, default: "squircle", values: ~w(circle squircle square)
  attr :class, :string, default: ""
  attr :rest, :global

  def avatar(assigns) do
    assigns =
      if is_nil(assigns.src) && assigns.email do
        assign(assigns, :src, avatar_from_email(assigns.email))
      else
        assigns
      end

    ~H"""
    <div class={["avatar", @class]} {@rest}>
      <div class={[
        shape_classes("mask", @shape),
        size_classes("avatar", @size)
      ]}>
        <img :if={@src} src={@src} alt={@alt} />
        <div :if={!@src} class="bg-neutral text-neutral-content flex items-center justify-center">
          <span class="text-xs">
            {(@email && to_string(@email) |> String.first() |> String.upcase()) || "?"}
          </span>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a confirmation modal dialog.

  ## Examples

      <.confirm_modal
        show={@show_confirm}
        title="Delete User"
        message="Are you sure you want to delete this user?"
        confirm_action="delete_user"
        confirm_text="Delete"
      />
  """
  attr :show, :boolean, required: true
  attr :id, :string, default: "confirm-modal"
  attr :title, :string, required: true
  attr :message, :string, required: true
  attr :confirm_action, :string, required: true
  attr :confirm_text, :string, default: "Confirm"
  attr :cancel_text, :string, default: "Cancel"
  attr :variant, :string, default: "error", values: ~w(primary secondary error warning)
  attr :rest, :global

  def confirm_modal(assigns) do
    ~H"""
    <div :if={@show} id={@id} class="modal modal-open" {@rest}>
      <div class="modal-box">
        <h3 class="font-bold text-lg">{@title}</h3>
        <p class="py-4">{@message}</p>
        <div class="modal-action">
          <.button variant="ghost" phx-click="close_modal">
            {@cancel_text}
          </.button>
          <.button variant={@variant} phx-click={@confirm_action}>
            {@confirm_text}
          </.button>
        </div>
      </div>
      <form method="dialog" class="modal-backdrop">
        <button type="button" phx-click="close_modal">close</button>
      </form>
    </div>
    """
  end

  @doc """
  Renders a form modal dialog.

  ## Examples

      <.form_modal
        show={@show_modal}
        id="invite-modal"
        title="Invite New Member"
        form_id="invite-form"
        submit_text="Send Invite"
        cancel_text="Cancel"
        phx_submit="submit_invite"
        phx_change="update_invite_form"
      >
        <:inner_block>
          <.input field={@form[:email]} label="Email Address" />
        </:inner_block>
      </.form_modal>
  """
  attr :show, :boolean, required: true
  attr :id, :string, default: "form-modal"
  attr :title, :string, required: true
  attr :form_id, :string, required: true
  attr :submit_text, :string, default: "Save"
  attr :cancel_text, :string, default: "Cancel"
  attr :class, :string, default: ""
  attr :phx_submit, :string, default: nil
  attr :phx_change, :string, default: nil
  attr :rest, :global

  slot :inner_block, required: true
  slot :actions, doc: "Optional custom actions slot"

  def form_modal(assigns) do
    ~H"""
    <div :if={@show} id={@id} class={["modal modal-open", @class]} {@rest}>
      <div class="modal-box">
        <h3 class="font-bold text-lg">{@title}</h3>
        <form id={@form_id} phx-submit={@phx_submit} phx-change={@phx_change} class="py-4">
          {render_slot(@inner_block)}

          <div class="modal-action">
            <%= if @actions != [] do %>
              {render_slot(@actions)}
            <% else %>
              <.button type="button" variant="ghost" phx-click="close_modal">
                {@cancel_text}
              </.button>
              <.button type="submit" variant="primary">
                {@submit_text}
              </.button>
            <% end %>
          </div>
        </form>
      </div>

      <form method="dialog" class="modal-backdrop">
        <button type="button" phx-click="close_modal">close</button>
      </form>
    </div>
    """
  end

  ## Helpers

  # Generates daisyUI size classes for various components
  defp size_classes(component, size) do
    case {component, size} do
      {"card", "sm"} -> "shadow-sm"
      {"card", "base"} -> "shadow-md"
      {"card", "lg"} -> "shadow-lg"
      {"card", "xl"} -> "shadow-xl"
      {"input", "xs"} -> "input-xs"
      {"input", "sm"} -> "input-sm"
      {"input", "base"} -> ""
      {"input", "lg"} -> "input-lg"
      {"badge", "xs"} -> "badge-xs"
      {"badge", "sm"} -> "badge-sm"
      {"badge", "base"} -> "badge-md"
      {"badge", "lg"} -> "badge-lg"
      {"avatar", "xs"} -> "w-6"
      {"avatar", "sm"} -> "w-8"
      {"avatar", "base"} -> "w-10"
      {"avatar", "lg"} -> "w-12"
      {"avatar", "xl"} -> "w-16"
      {"btn", "xs"} -> "btn-xs"
      {"btn", "sm"} -> "btn-sm"
      {"btn", "base"} -> ""
      {"btn", "lg"} -> "btn-lg"
      _ -> ""
    end
  end

  # Generates daisyUI variant classes for components
  defp variant_classes(component, variant) do
    case {component, variant} do
      {"badge", "primary"} -> "badge-primary"
      {"badge", "secondary"} -> "badge-secondary"
      {"badge", "accent"} -> "badge-accent"
      {"badge", "ghost"} -> "badge-ghost"
      {"badge", "neutral"} -> "badge-neutral"
      {"badge", "info"} -> "badge-info"
      {"badge", "success"} -> "badge-success"
      {"badge", "warning"} -> "badge-warning"
      {"badge", "error"} -> "badge-error"
      {"btn", "primary"} -> "btn-primary"
      {"btn", "secondary"} -> "btn-secondary"
      {"btn", "accent"} -> "btn-accent"
      {"btn", "ghost"} -> "btn-ghost"
      {"btn", "error"} -> "btn-error"
      {"btn", "success"} -> "btn-success"
      {"btn", "warning"} -> "btn-warning"
      _ -> ""
    end
  end

  # Generates mask shape classes for avatars
  defp shape_classes(component, shape) do
    case {component, shape} do
      {"mask", "circle"} -> "mask mask-circle"
      {"mask", "squircle"} -> "mask mask-squircle"
      {"mask", "square"} -> "mask mask-square"
      _ -> ""
    end
  end

  # Generates a placeholder avatar image from an email address
  defp avatar_from_email(email) do
    initial =
      email
      |> to_string()
      |> String.first()
      |> String.upcase()

    "https://placehold.co/80x80?text=#{initial}"
  end

  # Button component referenced by modals - assumes it exists in CoreComponents
  # If not, users should add this to their CoreComponents module
  defp button(assigns) do
    ~H"""
    <button
      type={assigns[:type] || "button"}
      class={["btn", variant_classes("btn", assigns[:variant] || "primary"), size_classes("btn", assigns[:size] || "base")]}
      {assigns_to_attributes(assigns, [:variant, :size, :type])}
    >
      {render_slot(assigns[:inner_block])}
    </button>
    """
  end
end
