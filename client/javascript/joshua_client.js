// Compiled from coffeescript source via https://coffeescript.org/

var RequestBase;

window.Api = function(path, opts = {}) {
  var form, request;
  if (typeof path !== 'string') {
    form = $(path);
    path = form.attr('action');
    opts = form.serializeHash();
  }
  if (path.indexOf('/api/') !== 0) {
    path = `/api/${path}`;
  }
  request = new RequestBase();
  fetch(path({
    method: 'POST',
    body: JSON.stringify(opts)
  })).then(request.complete);
  return request;
};

RequestBase = class RequestBase {
  constructor() {
    this.refresh = this.refresh.bind(this);
    this.reload = this.reload.bind(this);
    this.follow = this.follow.bind(this);
    this.error = this.error.bind(this);
    this.done = this.done.bind(this);
    this.redirect = this.redirect.bind(this);
    this.silent = this.silent.bind(this);
    this.complete = this.complete.bind(this);
  }

  refresh(node) {
    this.do_refresh = node || true;
    return this;
  }

  reload() {
    this.do_reload = true;
    return this;
  }

  follow(func) {
    this.do_follow = true;
    return this;
  }

  error(func) {
    this.error_func = func;
    return this;
  }

  done(func) {
    this.done_func = func;
    return this;
  }

  redirect(path) {
    this.redirect_to = path;
    return this;
  }

  silent(info) {
    this.is_silent = [info];
    return this;
  }

  complete(data, http_status) {
    var location, node, response;
    response = JSON.parse(data.responseText);
    if (response.error) {
      if (request.error_func) {
        request.error_func(response.error);
      } else {
        error_info(response);
      }
    }
    if (http_status === 'success') {
      if (!this.is_silent) {
        success_info(response);
      }
      if (this.done_func) {
        this.done_func(response);
      }
      if (this.redirect_to) {
        handle_redirect(this.redirect_to);
      }
      if (this.do_reload) {
        reload_page();
      }
      if (node = this.do_refresh) {
        if (typeof node === 'object') {
          Svelte('ajax', node).reload();
        } else {
          Pjax.refresh();
        }
      }
      if (this.do_follow) {
        location = data.getResponseHeader('location') || response.meta.path;
        if (location) {
          return load_page(location);
        } else {
          return error_info('Follow URL not found');
        }
      }
    }
  }

};
