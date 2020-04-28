# just execute action and trigger Info.api() buy default
# Api(path, opts)
#
# silent execute
# Api(path, opts).silent()
#
# trigger info and custom function on success
# Api(path, opts).done(function() { ... }) - info + done
#
# silent and redirect on sucess
# Api(path, opts).silent().redirect(path) - info and redirect on success
#
# silent on success, custom error func
# Api(path, opts).silent().error(error_func)

window.Api = (path, opts={}) ->
  if typeof(path) != 'string'
    form = $ path
    path = form.attr 'action'
    opts = form.serializeHash()

  path    = "/api/#{path}" unless path.indexOf('/api/') == 0
  request = new RequestBase()

  $.ajax
    type: 'POST'
    url:  path,
    data: opts,
    complete: request.complete

  request

class RequestBase
  refresh:  (node) => @do_refresh  = node || true; @
  reload:   =>        @do_reload   = true;   @
  follow:   (func) => @do_follow   = true;   @
  error:    (func) => @error_func  = func;   @
  done:     (func) => @done_func   = func;   @
  redirect: (path) => @do_redirect = path;   @
  silent:   (info) => @is_silent   = [info]; @
  complete: (data, http_status) =>
    response = JSON.parse(data.responseText)

    if response.error
      if request.error_func
        request.error_func(response.error)
      else
        Info.api(response)

    if http_status == 'success'
      Info.api(response)      unless @is_silent
      @done_func(response)    if @done_func
      Pjax.load(@do_redirect) if @do_redirect
      Pjax.reload()           if @do_reload

      if node = @do_refresh
        if typeof(node) == 'object'
          Svelte('ajax', node).reload()
        else
          Pjax.refresh()

      if @do_follow
        location = data.getResponseHeader('location') || response.meta.path

        if location
          Pjax.load(location)
        else
          Info.error 'Follow URL not found'

