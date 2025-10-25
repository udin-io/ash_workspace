defmodule AshWorkspaceTest do
  use ExUnit.Case
  doctest AshWorkspace

  test "greets the world" do
    assert AshWorkspace.hello() == :world
  end
end
