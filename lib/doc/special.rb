# reponse from /api/_/foo

class CleanApi
  module DocSpecial
    extend self

    def postman
      raw
    end

    def raw
      unwanted = %w(all member collection)
      {}.tap do |doc|
        for el in CleanApi.documented
          doc[el.to_s.sub(/Api$/, '').tableize] = el.opts.filter { |k, _| !unwanted.include?(k.to_s.split('_')[1]) }
        end
      end
    end
  end
end
