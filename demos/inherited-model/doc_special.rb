# Creates postman / insomnija documentation for models
# injects model attributes for create and update
# this works for ActiveRecord and Sequel models

class Joshua
  class DocSpecial
    def formdata_model opts
      model = opts.key.to_s.classify.constantize
      keys  = model.respond_to?(:column_names) ? model.column_names.map(&:to_sym) : model.columns
      keys  = keys - [:id, :created_at, :updated_at, :created_by, :updated_by]

      keys.map do |field|
        {
          key:         '%s[%s]' % [opts.key, field],
          description: '%s model field' % opts.key,
          disabled:    true
        }
      end
    end
  end
end