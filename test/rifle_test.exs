defmodule RifleTest do
  use ExUnit.Case
  doctest Rifle

  test "greets the world" do
    assert Rifle.hello() == :world
  end
end
