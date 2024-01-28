defmodule StatsdMetric.EmptyError do
  @moduledoc """
  An exception raised when the stat passed to the decoder is empty.
  """

  defexception message: "empty error"
end

defmodule StatsdMetric.NoKeyError do
  @moduledoc """
  An exception raised when the stat passed to the decoder has no key.
  """

  defexception message: "no key error"
end

defmodule StatsdMetric.NoValueError do
  @moduledoc """
  An exception raised when the stat passed to the decoder has no value.
  """

  defexception message: "no value error"
end

defmodule StatsdMetric.NoTypeError do
  @moduledoc """
  An exception raised when the stat passed to the decoder has no type.
  """

  defexception message: "no type error"
end
