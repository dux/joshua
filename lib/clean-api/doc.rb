class CleanApi
  module Doc
    extend self

    ICONS = {
      github:  {
        url:   'https://github.com/dux/clean-api',
        image: '<path d="M11.999 1.271C5.925 1.271 1 6.196 1 12.273c0 4.859 3.152 8.982 7.523 10.437.55.1.751-.239.751-.53l-.015-1.872c-3.06.666-3.706-1.474-3.706-1.474-.5-1.271-1.221-1.609-1.221-1.609-.999-.683.075-.668.075-.668 1.105.077 1.685 1.133 1.685 1.133.981 1.681 2.575 1.196 3.202.914.1-.711.384-1.196.698-1.471-2.442-.277-5.011-1.221-5.011-5.436 0-1.201.429-2.183 1.133-2.952-.114-.278-.491-1.397.108-2.911 0 0 .923-.296 3.025 1.127A10.56 10.56 0 0 1 12 6.591c.935.004 1.876.127 2.754.37 2.1-1.423 3.022-1.127 3.022-1.127.6 1.514.223 2.633.11 2.911.705.769 1.131 1.751 1.131 2.952 0 4.225-2.573 5.155-5.023 5.427.395.34.747 1.011.747 2.038 0 1.471-.014 2.657-.014 3.018 0 .293.199.636.756.528C19.851 21.251 23 17.13 23 12.273c0-6.077-4.926-11.002-11.001-11.002z"></path>',
      },
      twitter: {
        url:   'https://twitter.com/@dux',
        image: '<path d="M22.208 3.871c-.757.252-1.824.496-2.834.748-.757-.883-1.892-1.388-3.154-1.388-2.902 0-4.92 2.649-4.289 5.425-3.659-.126-6.939-1.892-9.083-4.542-1.135 1.892-.505 4.542 1.388 5.803-.757 0-1.388-.126-2.019-.505 0 2.145 1.388 4.037 3.532 4.416-.631.252-1.388.252-2.019.126.505 1.766 2.145 3.028 4.037 3.028-1.892 1.388-4.289 2.019-6.56 1.766 1.892 1.262 4.163 2.019 6.686 2.019 8.2 0 12.742-6.813 12.49-12.994.753-1.089 1.49-2.201 1.824-3.902z"></path>',
      },
      email: {
        url:   'mailto:reic.dino@gmail.com',
        image: '<path d="M22.22 9.787c0-5.13-4.062-8.307-8.983-8.307-6.666 0-11.457 4.948-11.457 11.431 0 6.042 4.609 9.609 9.999 9.609 1.64 0 3.749-.391 5.234-1.12l.364-2.031c-1.484.729-3.645 1.224-5.442 1.224-4.661 0-7.968-2.968-7.968-7.682 0-5.025 3.619-9.478 9.14-9.478 3.854 0 7.004 2.318 7.004 6.354 0 1.562-.39 3.671-1.588 4.843-.521.521-1.068.885-1.849.885-.599 0-1.015-.312-1.015-1.015 0-.235.052-.495.104-.729l1.614-6.458h-1.745l-.65 1.094c-.521-.938-1.615-1.381-2.63-1.381-3.386 0-5.208 3.151-5.208 6.25 0 1.198.416 2.291 1.197 3.047.599.598 1.485 1.041 2.5 1.041 1.328 0 2.422-.443 3.307-1.458.209.729 1.042 1.458 2.292 1.458 1.64 0 2.578-.625 3.541-1.562 1.536-1.484 2.239-3.828 2.239-6.015zm-7.916 1.276c0 1.77-.755 4.426-2.916 4.426-1.458 0-2.057-1.067-2.057-2.395 0-1.094.365-2.474 1.172-3.385.442-.495 1.015-.886 1.718-.886 1.406 0 2.083.886 2.083 2.24z"></path>',
      },
    }

    def tag
      HtmlTagBuilder
    end

    # render full page
    def render
      tag.html do |n|
        n.head  do |n|
          n.title 'CleanAPI Tester'
          n.link({ href: "https://fonts.googleapis.com/css?family=Inter:300,400,500,600,700,800,900&display=swap",  rel:"stylesheet" })
          n.link({ rel:"stylesheet", href:"https://stackpath.bootstrapcdn.com/bootstrap/4.4.1/css/bootstrap.min.css" })
          n.script({ src: 'https://cdnjs.cloudflare.com/ajax/libs/zepto/1.2.0/zepto.min.js' })
        end
        n.body do |n|
          n.style %[
            * { font-family: 'Inter', sans-serif; }
            .gutter { margin-left: 20px; }
            .api-method { border-top: 1px solid #ccc; padding: 20px 20px 10px 20px; border-top-color: #ccc; background-color: #eee; margin-bottom: 20px; }
            .sticky  { position: -webkit-sticky; position: sticky; top: 30px; }
            .btn-outline-info svg { fill: #17a2b8; }
            .btn-outline-info:hover svg { fill: #eee; }
            button.request { float: right; display: none; }
            .api-method:hover button.request { display: inline; }
            .anchor  { display: block; position: relative; top: -30px; visibility: hidden; }
            .btn { background-color: #fff; }
            .nav     { background-color: #fff; }
            body     { background-color: #fbfbfb; }
            pre      { padding-bottom: 10px; font-family: inherit;}
            h1.nav a { font-size: 22px; color: #383838; padding: 17px 0 18px 0; }
            h5       { font-size: 18px; font-weight: 600; }
            h5 a     { color: #333 !important; }
            h6       { color: #888; margin-bottom: 10px; -font-size: 13px; }
            gray     { color: #707070;  }
            b        { color: #666975; }
            svg      { margin: 0 5px; }
            bold     { font-weight: 600; }
            ul       { margin-left: -10px; margin-top: -5px;}
            form label { font-weight: bold; display: block; }

            #modal table td { padding-bottom: 15px; vertical-align: top; }
            #modal table td:first-child { padding: 10px 30px 0 0; }
          ]
          n._nav({ style: 'border-bottom: 1px solid rgb(228, 228, 228); margin-bottom: 40px;'}) do |n|
            n._container do |n|
              n.push top_icons
              n.h1({ class: :nav}) { %[<a href="#top">CleanApi &nbsp; <gray>Docs</gray></a>] }
            end
          end

          n.push modal_dialog

          n._container do |n|
            n._row do |n|
              n._col_3 do |n|
                n._sticky do |n|
                  n.a({ class: :dark, href: '#top' }) { '<p><b>API OBJECTS</b></p>' }
                  n.push left_nav

                  n.br
                  n.br
                  n.a({ class: :dark, href: '#top' }) { '<p><b>API LIBRARIES</b></p>' }
                  n.div do |n|
                    n.push %[<p><a class="badge badge-light" href="#">Ruby</a></p>]
                    n.push %[<p><a class="badge badge-light" href="#">Javascript</a></p>]
                    n.push %[<p><a class="badge badge-light" href="#">Python</a></p>]
                    n.push %[<p><a class="badge badge-light" href="#">C#</a></p>]
                  end
                end
              end

              n._col_9 { index }
            end
          end
        end
      end
    end

    # anchor link
    def name_link name
      %[<a name="#{name}" class="anchor"></a>]
    end

    # render single icon
    def icon data, size: 24, color: nil, style: nil
      %[<svg style="width: #{size}px; height: #{size}px; #{style}" viewBox="0 0 24 24" fill="currentColor">#{data}</svg>]
    end

    # top side navigation icons
    def top_icons
      tag.div({ style: 'float: right; margin-top: 20px;' }) do |n|
        for icon in ICONS.values
          n.push %[<a target="_new" href="#{icon[:url]}">#{icon icon[:image]}</a>]
        end
      end
    end

    # left side navigation
    def left_nav
      tag.div do |n|
        CleanApi.activated.each do |name|
          n.a({ class:'btn btn-outline-info btn-sm', style: '-font-size: 14px; margin-bottom: 10px;', href: '#%s' % name}) do |n|
            icon = name.opts.dig(:opts, :icon)
            n.push self.icon icon, size: 20 if icon
            n.push name.to_s.sub(/Api$/, '')
          end

          n.br
        end
      end
    end

    # render doc for all activated classes
    def index
      tag.div do |n|
        for @klass in CleanApi.activated
          @opts = @klass.opts
          icon = @opts.dig(:opts, :icon)

          n.push name_link @klass
          n.push self.icon icon, style: 'position: absolute; margin-left: -40px; margin-top: 1px; fill: #777;' if icon
          n.h4 { @klass.to_s.sub(/Api$/, '') }

          if desc = @opts.dig(:opts, :desc)
            n.p { desc }
          end

          if detail = @opts.dig(:opts, :detail)
            n.p { detail }
          end

          n.push render_type :member
          n.push render_type :collection

          n.br
          n.hr
          n.br
        end
      end
    end

    # render members or collection
    def render_type name
      base = @opts[name] || return

      tag.div do |n|
        n.br
        n.h5 '<gray>%s methods</gray>' % name

        for m_name, member in base
          n.div do |n|
            n.push render_method name: name, m_name: m_name, opts: member
          end
        end
      end
    end

    # render api method
    def render_method name:, m_name:, opts:
      tag._api_method do |n|
        # n.push %[<button onclick="" class="btn btn-info btn-sm request">request</button>]
        anchor = [@klass, m_name].join('-')

        n.push name_link anchor
        n.h5 do |n|
          n.push "<a href='##{anchor}'>#{m_name}</a>"
          n.push ' <gray>&nbsp; &mdash; &nbsp; %s</gray>' % opts[:desc] if opts[:desc]
        end

        n.p({style: 'margin: 20px 0 25px 0;'}) do |n|
          path = "/api/#{@klass.api_path}"
          path += '/:id' if name == :member
          path += "/#{m_name}"
          n.push %[<button href="#{path}" class="btn btn-light btn-sm" onclick='render_call(this.innerHTML, #{(opts[:params] || {}).to_json})'>#{path}</button>]
        end

        if opts[:detail]
          n.h6 'Details'
          n.pre opts[:detail]
        end

        if mopts = opts[:params]
          n.h6 'Params'
          n.ul do |n|
            for name, opt in mopts
              n.li do |n|
                n.push '<bold>%s</bold>: ' % name
                n.push opt[:type]

                data = []
                data.push 'required' if opt[:required]
                data.push 'default: %s' % opt[:default].to_s unless opt[:default].nil?
                n.push ' &mdash; (%s)' % data.join(', ') if data.length > 0
              end
            end
          end
        end
      end
    end

    def modal_dialog
      %[
        <script>
        window.Modal = {
          render: function (title, data) {
            $('#modal .modal-title').html(title)
            $('#modal .modal-body').html(data)
            $('#modal').show()
          },
          close: function () {
            $('#modal').hide()
          }
        }

        window.render_call = function (title, params) {
          let data = []

          data.push(`<form onsubmit="ApiCall.fetch('${title}', this); return false;">`)
          data.push(`  <table>`)

            if (title.includes('/:id/')) {
              data.push(`    <tr><td><label>ID</label></td><td><input id="api_id_value" type="text" class="form-control" value="" /></td></tr>`)
            }

          for (let [name, vals] of Object.entries(params)) {
            data.push(`  <tr>`)
            data.push(`    <td><label>${name}</label></td><td>`)

            if (vals.type == 'boolean') {
              data.push(`    <input type="checkbox" class="form-control" name="${name}" />`)
            } else {
              data.push(`    <input type="text" class="form-control" name="${name}" value="" />`)
            }

            if (vals.default) {
              data.push(`<small class="form-text text-muted">default: ${vals.default}</small>`)
            }

            data.push(`    </td></tr>`)
          }

          data.push(`  <tr><td></td><td><button class="btn btn-outline-primary">Execute API request</button></td></tr>`)
          data.push(`  </table>`)
          data.push(`</form>`)

          data = `${data.join("\\n")}<div id="api_result"></div>`

          Modal.render(title, data);
        }

        document.onkeydown = function(evt) {
          evt = evt || window.event;
          if (evt.keyCode == 27) {
            Modal.close();
          }
        };

        window.ApiCall = {
          fetch: function(url, form) {
            let post = $(form).serialize()

            url = url.replace('/:id/', () => '/'+$('#api_id_value').val()+'/' )

            full_url = url
            if (post) full_url += `?${post}`

            ApiCall.insert('...')

            $.post(url, post, function(data) {
              ApiCall.insert(JSON.stringify(data, null, 2))
            })
          },

          insert: function(data) {
            let out = []
            out.push(`<div id="api_response"><hr /><button class="btn btn-sm btn-outline-info" style="float: right;" onclick="$('#api_response').remove()">close</button>`)
            out.push(`<pre><a href="${full_url}">${full_url}</a>`)
            out.push(data)
            out.push(`</pre></div>`)
            $('#api_result').html(out.join("\\n\\n"))
          }
        }

        </script>
        <div id="modal" class="modal" tabindex="-1" role="dialog">
          <div style="position: absolute; top: 0; left: 0; width: 100%; height: 100%; background: rgba(99,99,99,0.3)"></div>
          <div class="modal-dialog modal-lg" role="document">
            <div class="modal-content">
              <div class="modal-header">
                <h5 class="modal-title"></h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close" onclick="Modal.close()">
                  <span aria-hidden="true">&times;</span>
                </button>
              </div>
              <div class="modal-body">
              </div>
            </div>
          </div>
        </div>
      ]
    end
  end
end