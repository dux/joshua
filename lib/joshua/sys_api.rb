# Reserved /sys namespace: serves introspection JSON, generator outputs
# (postman, openapi) and a health probe. Inherits straight from Joshua to
# stay outside any user-defined ApplicationApi callback stack.

class Joshua
  class SysApi < Joshua
    class_desc 'Joshua system endpoints: introspection, schema export, health.'

    allow :get
    desc 'Raw introspection schema (single source of truth for all generators).'
    def schema
      response('application/json') do
        JSON.pretty_generate(Joshua::Introspect.schema(mount_on: derive_mount_on))
      end
    end

    allow :get
    desc 'Postman collection v2.1, built from the introspection schema.'
    def postman
      response('application/json') do
        Joshua::PostmanSchema.new(@api, mount_on: derive_mount_on).postman
      end
    end

    allow :get
    desc 'OpenAPI 3 specification, built from the introspection schema.'
    def openapi
      response('application/json') do
        JSON.pretty_generate(Joshua::OpenapiSchema.new(@api, mount_on: derive_mount_on).openapi)
      end
    end

    allow :get
    desc 'Interactive API explorer. Default response is index.html; pass ?file=joshua-nav.fez (or any whitelisted file under lib/web/) to fetch a specific asset. Content-Type is inferred from the extension.'
    def web
      result = Joshua::Web.render(file: @api.params[:file])
      response(result[:content_type]) { result[:body] }
    rescue ArgumentError => e
      response.error e.message, status: 400
    end

    allow :get
    desc 'Health probe.'
    def health
      response('application/json') do
        { ok: true, schema_version: Joshua::Introspect::SCHEMA_VERSION }.to_json
      end
    end

    private

    # Recover the actual mount prefix from the live request path; this is
    # more reliable than OPTS[:api][:mount_on], which is global state that
    # the last-loaded class wins.
    def derive_mount_on
      path = @api.request&.path
      return OPTS.dig(:api, :mount_on) || '/' unless path

      # "/api/sys/schema" -> "/api"
      prefix = path.split('/sys/').first.to_s
      prefix.empty? ? '/' : prefix
    end
  end
end
