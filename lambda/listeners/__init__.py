from .assistant import assistant


def register_listeners(app):
    # Using assistant middleware is the recommended way.
    app.assistant(assistant)
