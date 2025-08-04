defmodule VsmPhoenixWeb.ChangesetView do
  use Phoenix.Component
  import VsmPhoenixWeb.Gettext
  
  @doc """
  Traverses and translates changeset errors.
  
  See `Ecto.Changeset.traverse_errors/2` for more details.
  """
  def render("error.json", %{changeset: changeset}) do
    # When encoded, the changeset returns its errors
    # as a JSON object. So we just pass it forward.
    %{errors: translate_errors(changeset)}
  end
  
  def translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, &translate_changeset_error/1)
  end
  
  def translate_changeset_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate "is invalid" in the "errors" domain
    #     dgettext("errors", "is invalid")
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # Because the error messages we show in our forms and APIs
    # are defined inside Ecto, we need to translate them dynamically.
    # This requires us to call the Gettext module passing our gettext
    # backend as first argument.
    #
    # Note we use the "errors" domain, which means translations
    # should be written to the errors.po file. The :count option is
    # set by Ecto and indicates we should also apply plural rules.
    if count = opts[:count] do
      Gettext.dngettext(VsmPhoenixWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(VsmPhoenixWeb.Gettext, "errors", msg, opts)
    end
  end
end