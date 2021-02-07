# reponse from /api/_/foo

class Joshua
  class DocSpecial
    def initialize api
      @api = api
    end

    def postman
      out = {
        info: {
          _postman_id: request.url,
          _bearer_token: @api[:bearer],
          name: request.host,
          schema: "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
        },
        item: []
      }

      for table, data in raw
        raw_data = raw[table.to_s]
        hash = {}
        hash[:name] = table
        hash[:item] = []

        for type in [:collection, :member]
          next unless raw_data[type]

          if raw_data[type]
            items = []

            for key, value in raw_data[type]
              items.push postman_add_method(type, table, key, value)
            end

            hash[:item].push *items
            # hash[:item].push({
            #   name: type,
            #   item: items
            # })
          end
        end

        out[:item].push hash
      end

      @api[:development] ? JSON.pretty_generate(out) : out.to_json
    end

    def raw
      unwanted = %w(all member collection)
      {}.tap do |doc|
        for el in Joshua.documented
          doc[el.to_s.sub(/Api$/, '').underscore] = el.opts.filter do |k, v|
            for k1, v1 in v
              if v1.is_a?(Hash)
                for k2 in v1.keys
                  # remove Typero
                  v1.delete(k2) if k2.to_s.start_with?('_')
                end
              end
            end

            !unwanted.include?(k.to_s.split('_')[1])
          end
        end
      end
    end

    private

    def postman_add_method type, table, name, item
      path = []

      base = request.url.split('/_/').first
      base = base.split('/')

      path.push base.pop
      base = base.join('/')

      path.push table
      path.push ':id' if type == :member
      path.push name

      name = '%s*' % name if type == :collection

      out = {
        name: name,
        request: {
          method: 'POST',
          header: [],
          url: {
            raw:      ([base] + path).join('/'),
            protocol: base.split(':').first,
            host:     request.host.split('.'),
            port:     request.port,
            path:     path
          },
        }
      }

      for key, value in (item[:params] || {})
        out[:request][:body] ||= { mode: 'formdata', formdata: [] }

        formdata_custom = 'formdata_%s' % value[:type]

        # if value[:type] == 'model' and key == 'user' you can define "formdata_model"
        # that returns list of fields for defined model
        formdata_value =
        if respond_to?(formdata_custom)
          opts = { key: key, value: value, name: name, type: type, group: table }
          [send(formdata_custom, opts.to_hwia)].flatten
        else
          { key: key, description: value[:type] }
        end

        formdata_value = [formdata_value] unless formdata_value.is_a?(Array)
        out[:request][:body][:formdata].push *formdata_value
      end

      out
    end

    def request
      @api[:api_host].request
    end
  end
end
