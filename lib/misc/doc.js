// global state
window.State = {
  active_tab: 'response',
  request:    {},
  full_url:   '',

  set_request: (full_url) => {
    State.full_url = full_url

    parts    = full_url.split('?')
    parts[1] = parts[1] || ''

    State.request = {
      host:   api_opts.mount_on,
      path:   parts[0].replace(api_opts.mount_on, ''),
      params: parts[1],
      object: {}
    }

    for (el of parts[1].split('&')) {
      let [key, value] = el.split('=', 2)
      State.request.object[key] = value
    }

    return State.request
  },
}

// generic modal interface
window.Modal = {
  render: (title, data) => {
    $('#modal .modal-title').html(title)
    $('#modal .modal-body').html(data)
    $('#modal').show()
  },
  close: () => {
    $('#modal').hide()
  }
}

// form in modal box
window.ModalForm = {
  render: (title, params) => {
    let data = []

    data.push(`<form onsubmit="TabResponse.render('${title}', this); return false;">`)
    data.push(`  <table>`)

      if (title.includes('/:id/')) {
        data.push(`    <tr><td><label>ID</label></td><td><input id="api_id_value" type="text" class="form-control" value="" autocomplete="off"  /></td></tr>`)
      }

    for (let [name, vals] of Object.entries(params)) {
      data.push(`  <tr>`)
      data.push(`    <td><label>${name}</label></td><td>`)

      if (vals.type == 'boolean') {
        data.push(`    <input type="checkbox" class="form-control" name="${name}" />`)
      } else {
        data.push(`    <input type="text" class="form-control" name="${name}" value="" autocomplete="off" />`)
      }

      if (vals.default) {
        data.push(`<small class="form-text text-muted">default: ${vals.default}</small>`)
      }

      data.push(`    </td></tr>`)
    }

    data.push(`  <tr><td></td><td><button class="btn btn-outline-primary">Execute API request</button></td></tr>`)
    data.push(`  </table>`)
    data.push(`</form>`)

    data = `${data.join("\n")}<div id="api_result"></div>`

    Modal.render(title, data);
  }
}

// backend api call
window.TabResponse = {
  render: (url, form) => {
    let post   = $(form).serialize()
    let id_val = $('#api_id_value').val()

    if (id_val) {
      url = url.replace('/:id/', () => '/'+id_val+'/' )
    }

    full_url = url
    if (post) full_url += `?${post}`

    if (url.includes('/:id/')) {
      alert('ID is not defined')
      return
    }

    State.set_request(full_url)

    TabResponse.render_tab_data()

    $.post(url, post, (data) => {
      State.response = data;
      TabResponse.render_tab_data()
    })
  },

  setActiveTab: (node, name) => {
    let el = $(node)
    // debugger
    el.parents('ul').find('a').removeClass('active')
    el.addClass('active')

    State.active_tab = name
    TabResponse.render_tab_data()
  },

  render_tab_data: () => {
    let tabs   = ['response', 'curl', 'javascript', 'ruby']

    let out = []
    out.push(`<div id="api_response"><br /><button class="btn btn-sm btn-outline-info" style="float: right; margin-top: -4px; margin-bottom: -30px;" onclick="$('#api_response').remove()">close</button>`)

    out.push(`<ul class="nav nav-tabs" style="margin-left:0; margin-bottom: 15px;">`)

    for (name of tabs) {
      let is_active = State.active_tab == name ? ' active' : ''
      out.push(`<li class="nav-item"><a class="nav-link ${is_active}" href="#" onclick="TabResponse.setActiveTab(this, '${name}'); return false;">${name}</a></li>`)
    }

    out.push(`</ul>`)

    out.push(TabResponse.format[State.active_tab]())
    $('#api_result').html(out.join("\n\n"))
  },

  format: {
    response: () => {
      let data = JSON.stringify(State.response || {}, null, 2)
      let url  = `<a href="${State.full_url}">${State.full_url}</a>`

      return `<p>${url}</p><pre class="code">${data}</pre></div>`
    },

    curl: () => {
      out = []

      out.push(`# PS: you can send post data as JSON as well`)
      out.push(`# JSON export is a default, "Accept: application/json" header is not needed`)
      out.push(``)

      out.push(`curl -X POST\\`)

      let token = AuthButton.get()
      if (token) {
        out.push(`  -H "Authorization: Bearer ${token}"\\`)
      }

      url = State.request

      if (url.params) out.push(`  --data '${url.params}'\\`)

      out.push(`  ${url.host}${url.path}`)

      let parts = url.path.split('/')

      let opts = {
        id:     'foo-rand',
        class:  parts.shift(),
        action: parts,
        params: State.request.object,
        token:  token
      }

      out.push(``)
      out.push(`# or json rpc style`)
      out.push(`curl -X POST\\`)
      out.push(`  --data '${JSON.stringify(opts)}'\\`)
      out.push(`  ${url.host.replace(/\/$/, '')}`)

      return `<pre class="code">${out.join("\n")}</pre></div>`
    },

    ruby: () => {
      out = []

      let params = JSON.stringify(State.request.object)
      let parts  = State.request.path.split('/')

      out.push `# gem install 'clean-api'`
      out.push `require 'clean-api/remote'\n`

      out.push(`api = CleanApiRemote.new '${State.request.host.replace(/\/$/, '')}'`)

      let token = AuthButton.get()
      if (token) {
        out.push(`api.auth_token = '${token}'`)
      }

      if (parts[2]) {
        out.push(`api.${parts[0]}](${parts[1]}).${parts[2]}(${params})`)
        out.push(`# or -> api.call('${parts[0]}/${parts[1]}/${parts[2]}', ${params})`)
        out.push(`# or -> api.call(:${parts[0]}, ${parts[1]}, :${parts[2]}, ${params})`)
      } else {
        out.push(`api.${parts[0]}.${parts[1]}(${params})`)
        out.push(`# or -> api.call('${parts[0]}/${parts[1]}', ${params})`)
        out.push(`# or -> api.call(:${parts[0]}, :${parts[1]}, ${params})`)
      }

      out.push(`api.success?`)
      out.push(`api.response`)
      return `<pre class="code">${out.join("\n")}</pre></div>`
    },

    javascript: () => {
      out = []
      out.push(`const axios = require('axios').default;`)
      out.push(``)
      out.push(`axios.post(`)
      out.push(`  '${State.full_url.split('?')[0]}',`)
      out.push(`  ${JSON.stringify(State.request.object)},`)

      let token = AuthButton.get()
      if (token) {
        out.push(`  { headers: { Authorization: 'Bearer ${token}' } }`)
      }

      out.push(`).then((response) => { });`)
      return `<pre class="code">${out.join("\n")}</pre></div>`
    }
  }
}

// auth botton
window.AuthButton = {
  set: () => {
    let token = prompt('Bearer token?', AuthButton.get() || '')

    if (token != null) {
      localStorage.setItem('auth_token', token)
    }

    AuthButton.draw()
  },

  get: () => {
    return localStorage.getItem('auth_token') || api_opts.bearer
  },

  draw: () => {
    let value = AuthButton.get()
    let text  = value ? `Yes` : 'n/a'

    $('#bearer_button').html(`Bearer Auth: <bold>${text}</bold>`)
  }
}

AuthButton.draw()


// close dialog on escape
document.onkeydown = (evt) => {
  evt = evt || window.event;
  if (evt.keyCode == 27) {
    Modal.close();
  }
};


