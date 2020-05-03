window.Api = (path, opts={}) ->
  if typeof(path) != 'string'
    form = $ path
    path = form.attr 'action'
    opts = form.serializeHash()

  path    = "/api/#{path}" unless path.indexOf('/api/') == 0
  request = new RequestBase()

  fetch path
    method: 'POST'
    body: JSON.stringify(opts),
  .then request.complete

  request

class RequestBase
  refresh:  (node) => @do_refresh  = node || true; @
  reload:   =>        @do_reload   = true;   @
  follow:   (func) => @do_follow   = true;   @
  error:    (func) => @error_func  = func;   @
  done:     (func) => @done_func   = func;   @
  redirect: (path) => @redirect_to = path;   @
  silent:   (info) => @is_silent   = [info]; @
  complete: (data, http_status) =>
    response = JSON.parse(data.responseText)

    if response.error
      if @error_func
        @error_func(response.error)
      else
        error_info(response)

    if http_status == 'success'
      success_info(response)        unless @is_silent
      @done_func(response)          if @done_func
      handle_redirect(@redirect_to) if @redirect_to
      reload_page()                 if @do_reload

      if node = @do_refresh
        if typeof(node) == 'object'
          Svelte('ajax', node).reload()
        else
          Pjax.refresh()

      if @do_follow
        location = data.getResponseHeader('location') || response.meta.path

        if location
          load_page(location)
        else
          error_info 'Follow URL not found'

