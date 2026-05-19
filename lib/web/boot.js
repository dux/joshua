// Boot script for the Joshua API explorer.
//   1. window.joshua: bearer storage + schema URLs
//   2. PostWind shortcuts (Stripe/Scalar-inspired light theme + dark code pane)
//   3. wire up header (links, bearer toggle, search filter)
//   4. fetch /sys/schema, populate nav + content
//
// Joshua is JSON-RPC style: every action is reached via POST. The UI does
// NOT show REST verb pills - the snippets and try-it always POST.

(function () {
  const sysBase = location.pathname.split('/sys/')[0] + '/sys';

  // ?api_key=XXX  =>  adopt as bearer, then strip from the URL so refresh /
  // bookmarks don't re-leak the token. Runs BEFORE window.joshua is built so
  // the new value is picked up on first read.
  {
    const u   = new URL(location.href);
    const key = u.searchParams.get('api_key');
    if (key) {
      localStorage.setItem('joshua_bearer', key);
      u.searchParams.delete('api_key');
      history.replaceState(null, '', u.toString());
    }
  }

  window.joshua = {
    bearer:      localStorage.getItem('joshua_bearer') || '',
    api_schema:  null,
    sys_base:    sysBase,
    schema_url:  sysBase + '/schema',
    postman_url: sysBase + '/postman',
    openapi_url: sysBase + '/openapi',
    setBearer(value) {
      this.bearer = (value || '').trim();
      if (this.bearer) localStorage.setItem('joshua_bearer', this.bearer);
      else             localStorage.removeItem('joshua_bearer');
      window.dispatchEvent(new CustomEvent('joshua:bearer-changed', { detail: this.bearer }));
    }
  };

  // --- PostWind ------------------------------------------------------------

  // Typography + buttons + labels are defined as plain CSS (in index.html
  // <style> and component <style> blocks). PostWind is here only for the
  // Tailwind atomic utilities used for layout/spacing/colors.
  PostWind.init({ tailwind: true, body: true });

  // --- DOM wiring ----------------------------------------------------------

  document.addEventListener('DOMContentLoaded', function () {
    for (const id of ['link-schema', 'ref-schema'])  document.getElementById(id).href = window.joshua.schema_url;
    for (const id of ['link-postman','ref-postman']) document.getElementById(id).href = window.joshua.postman_url;
    for (const id of ['link-openapi','ref-openapi']) document.getElementById(id).href = window.joshua.openapi_url;

    // bearer
    const row    = document.getElementById('bearer-row');
    const input  = document.getElementById('bearer-input');
    const mark   = document.getElementById('bearer-mark');
    const sync   = () => { mark.textContent = window.joshua.bearer ? '✓' : '·'; };
    input.value  = window.joshua.bearer;
    sync();
    document.getElementById('bearer-toggle').onclick = () => row.hidden = !row.hidden;
    document.getElementById('bearer-save').onclick   = () => { window.joshua.setBearer(input.value); sync(); };
    document.getElementById('bearer-clear').onclick  = () => { input.value = ''; window.joshua.setBearer(''); sync(); };
    window.addEventListener('joshua:bearer-changed', sync);

    // filter
    const search = document.getElementById('search-input');
    if (search) search.addEventListener('input', () => filterActions(search.value.trim().toLowerCase()));

    // schema
    Fez.fetch(window.joshua.schema_url, function (schema) {
      window.joshua.api_schema = schema;
      window.dispatchEvent(new CustomEvent('joshua:schema-loaded', { detail: schema }));
      renderNav(schema);
      renderContent(schema);
    });
  });

  // --- nav -----------------------------------------------------------------

  function renderNav(schema) {
    const ul = document.getElementById('nav-apis');
    ul.innerHTML = '';
    for (const name of Object.keys(schema.apis)) {
      const api = schema.apis[name];
      const actions = [
        ...Object.keys(api.collection || {}).map(a => ({ a, kind: 'collection' })),
        ...Object.keys(api.member     || {}).map(a => ({ a, kind: 'member'     })),
      ];

      const items = actions.map(({ a, kind }) => `
        <li><a href="#method-${name}-${a}" data-search="${name} ${a}"
            class="flex items-center gap-2 px-2 py-0.5 rounded hover:bg-gray-100 text-gray-600 hover:text-gray-900 no-underline small-text">
          <code>${a}</code>
          ${kind === 'member' ? '<span class="label purple" style="padding:0 4px;">:ref</span>' : ''}
        </a></li>
      `).join('');

      const li = document.createElement('li');
      li.dataset.search = name;
      li.innerHTML = `
        <a href="#api-${name}" class="block mb-1 no-underline"><h6 style="color:#374151;">${name}</h6></a>
        <ul class="space-y-0.5">${items}</ul>
      `;
      ul.appendChild(li);
    }
  }

  // --- main content --------------------------------------------------------

  function renderContent(schema) {
    const root = document.getElementById('apis-content');
    root.innerHTML = '';

    for (const name of Object.keys(schema.apis)) {
      const el = document.createElement('joshua-api');
      el.props = { name, api: schema.apis[name], mount_on: schema.mount_on };
      root.appendChild(el);
    }

    const errs = schema.errors || {};
    if (Object.keys(errs).length) root.appendChild(renderErrors(errs));
  }

  function renderErrors(errors) {
    const section = document.createElement('section');
    section.id = 'named-errors';
    section.className = 'pt-8 border-t border-gray-200';

    const rows = Object.keys(errors).map(code => `
      <div class="flex items-baseline gap-3 px-3 py-2 border-b border-gray-100 last:border-0">
        <code class="text-rose-700">${code}</code>
        <span class="small-text text-gray-600">${errors[code]}</span>
      </div>
    `).join('');

    section.innerHTML = `
      <h6 class="mb-2">Named errors</h6>
      <div class="rounded-lg border border-gray-200 overflow-hidden bg-white">${rows}</div>
    `;
    return section;
  }

  // --- search filter -------------------------------------------------------

  function filterActions(q) {
    document.querySelectorAll('#nav-apis [data-search]').forEach(el => {
      const m = !q || el.dataset.search.toLowerCase().includes(q);
      el.style.display = m ? '' : 'none';
    });
  }
})();
