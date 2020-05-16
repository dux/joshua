# reponse from /api/_/foo

class Joshua
  class DocSpecial
    def initialize api
      @api = api
    end

    def postman
      out = {
        info: {
          _postman_id: @api[:request].url,
          name: @api[:request].host,
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

      out.to_json
    end

    def raw
      unwanted = %w(all member collection)
      {}.tap do |doc|
        for el in Joshua.documented
          doc[el.to_s.sub(/Api$/, '').underscore] = el.opts.filter { |k, _| !unwanted.include?(k.to_s.split('_')[1]) }
        end
      end
    end

    private

    def postman_add_method type, table, name, item
      path = []

      base = @api[:request].url.split('/_/').first
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
            host:     @api[:request].host.split('.'),
            port:     @api[:request].port,
            path:     path
          }
        },
      }

      item[:params] ||= { 'user[name]' => {} }

      for key, value in (item[:params] || {})
        out[:request][:body] ||= { mode: 'formdata', formdata: [] }
        out[:request][:body][:formdata].push({ key: key, description: value[:type] })
      end

      out
    end
  end
end
