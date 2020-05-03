# This is generic api implementation for Ruby Sequel https://sequel.jeremyevans.net/
# Active record implementation will require little modifications

class ModelApi < ApplicationApi

  class << self
    def generate name, desc: nil, detail: nil
      model_name  = to_s.sub(/Api$/, '').tableize.singularize.humanize.downcase
      method_name = 'generated_%s' % name
      desc ||= '%s %s' % [name.to_s.capitalize, model_name]

      raise '%s not found' % method_name unless method_name

      member do
        self.desc   desc   if desc
        self.detail detail if detail
        define_method(name) do
          error "Model not found" unless @model
          send('generated_%s' % name)
        end
      end
    end
  end

  ###

  before do
    # load generic model based on class name
    base = self
      .class
      .to_s
      .sub(/Api$/, '')
      .singularize
      .constantize

    if @api.id
      @model = base.find @api.id
      error 'Object %s[%s] is not found' % [base, @api.id] unless @model
    else
      @model = base.new
    end
  end

  after do
    if @model.try(:id)
      response.meta :path, @model.path
      response.meta :string_id, @model.id.string_id
    end
  end

  ###

  # toggles value in postgre array field
  def toggle_value field, value
    @model[field] ||= []

    if @model[field].include?(value)
      @model[field] -= [value]
      @model.save
      false
    else
      @model[field] += [value]
      @model.save
      true
    end
  end

  def report_errros_if_any
    return if @model.errors.count == 0

    ap ['MODEL API ERROR, params ->', params]

    for k, v in @model.errors
      desc = v.join(', ')

      response.error k, desc
    end
  end

  def model_params
    params[@model.class.to_s.underscore] || params
  end

  def display_name
    klass = @model.class

    if klass.respond_to?(:display_name)
      klass.display_name
    else
      klass.to_s.humanize
    end
  end

  def generated_show
    @model
      .can
      .read!
      .attributes
  end

  ###

  def generated_create
    @model = @class_name.constantize.new

    for k, v in model_params
      v = nil if v.blank?
      @model.send("#{k}=", v) if @model.respond_to?("#{k}=")
    end

    @model.can.create!

    @model.save if @model.valid?

    report_errros_if_any

    if @model.id
      message '%s created' % display_name
    else
      error 'model not created, error unknown'
    end

    attributes
  end

  def generated_update
    for k, v in model_params
      k = k.to_s
      v = v.xuniq if v.is_a?(Array)

      db_type = @model.db_schema.dig(k.to_sym, :db_type)

      v = nil if v.blank?
      m = "#{k}=".to_sym

      if db_type.to_s.include?('json')
        @model[k.to_sym] = @model[k.to_sym].merge(v)
      else
        @model.send(m, v) if @model.respond_to?(m)
      end
    end

    @model.can.update!

    @model.updated_at = Time.now.utc if @model.respond_to?(:updated_at)
    @model.save if @model.valid?

    report_errros_if_any

    message '%s updated' % display_name

    @model.api_export
  end

  # if you put active boolean field to models, then they will be unactivated on destroy
  def generated_destroy force: false
    @model.can.delete!

    if !force && @model.respond_to?(:is_deleted)
      @model.update is_deleted: true

      message 'Object deleted (exists in trashcan)'
    else
      @model.destroy
      message '%s deleted' % display_name
      @model = nil
    end

    report_errros_if_any

    @model.api_export
  end

  def generated_undelete
    @model.can.create!

    if @model.respond_to?(:is_deleted)
      @model.update is_deleted: false
    else
      error "No is_deleted field, can't undelete"
    end

    message = 'Object raised from the dead.'
  end
end
