# Generic model api, dynamicly creates api classes and methods

class ModelApi < ApplicationApi

  def self.generate name, desc: nil, detail: nil
    object_name = to_s.sub(/Api$/, '').tableize.singularize.humanize.downcase
    method_name = 'generated_%s' % name
    desc ||= '%s %s' % [name.to_s.capitalize, object_name]

    raise '%s not found' % method_name unless method_name

    if name == :create
      collection do
        self.desc   desc   if desc
        self.detail detail if detail
        self.params do
          self.set object_name, :model
        end
        define_method(name) { send('generated_%s' % name) }
      end
    else
      member do
        self.desc   desc   if desc
        self.detail detail if detail
        if name == :update
          self.params do
            self.set object_name, :model
          end
        end
        define_method(name) { send('generated_%s' % name) }
      end
    end
  end

  before do
    # load generic object based on class name
    base = self
      .class
      .to_s
      .sub(/Api$/, '')
      .singularize
      .constantize

    if @api.id
      @object = base.find @api.id
      error 'Object %s[%s] is not found' % [base, @api.id] unless @object
    else
      @object = base.new
    end

    instance_variable_set '@%s' % base.to_s.underscore, @object
  end

  after do |object|
    if object.try(:id)
      response.meta :path, object.path
      response.meta :id, object.id
    end
  end

  ###

  def same_as_last?
    return unless respond_to?(:created_by)

    @last = self.class.xorder('id desc').my.first

    return unless @last

    if respond_to?(:created_at)
      diff = (Time.now.to_i - @last.created_at.to_i)
      return diff < 2
    end

    if respond_to?(:name)
      return true if name == @last.name
    end

    false
  end

  # toggles value in postgre array field
  def toggle_value object, field, value
    object[field] ||= []

    if object[field].include?(value)
      object[field] -= [value]
      object.save
      false
    else
      object[field] += [value]
      object.save
      true
    end
  end

  def report_errros_if_any
    return if @object.errors.count == 0

    for el in @object.errors
      msg = [el.attribute.to_s.capitalize, el.message].join(' ')
      response.error_detail el.attribute, msg
    end
  end

  def object_params
    params[@object.class.to_s.underscore] || params
  end

  def display_name
    klass = @object.class

    if klass.respond_to?(:display_name)
      klass.display_name
    else
      klass.to_s.humanize
    end
  end

  def generated_show
    @object
      .attributes
  end

  ###

  def generated_create
    for k, v in object_params
      v = nil if v.blank?
      @object.send("#{k}=", v) if @object.respond_to?("#{k}=")
    end

    @object.can.create!

    @object.save if @object.valid?

    return if report_errros_if_any

    if @object.id
      message '%s created' % display_name
    else
      error 'object not created, error unknown'
    end

    true
  end

  def generated_update
    error "Object not found" unless @object

    # toggle array or hash field presence
    # toggle__field__value = 0 | 1
    for k, v in object_params
      k = k.to_s
      v = v.xuniq if v.is_a?(Array)

      # db_type = @object.db_schema.dig(k.to_sym, :db_type)
      db_type = @object.class.columns.find { |c| c.name == k.to_s }.type.to_s

      if k.starts_with?('toggle__')
        field, value = k.split('__').drop(1)

        value = value.to_i if db_type.include?('int')

        if @object[field.to_sym].class.to_s.include?('Array')
          # array field
          @object.send('%s=' % field, @object.send(field).to_a - [value])
          @object.send('%s=' % field, @object.send(field).to_a + [value]) if v.to_i == 1
        else
          # jsonb field, toggle true false
          @object.send(field)[value] = v.to_i == 1
        end

        next
      end

      v = nil if v.blank?
      m = "#{k}=".to_sym

      if db_type.to_s.include?('json')
        @object[k.to_sym] = @object[k.to_sym].merge(v)
      else
        @object.send(m, v) if @object.respond_to?(m)
      end
    end

    @object.can.update!

    @object.updated_at = Time.now.utc if @object.respond_to?(:updated_at)
    @object.save if @object.valid?

    report_errros_if_any

    response.message '%s updated' % display_name

    @object.attributes
  end

  # if you put active boolean field to objects, then they will be unactivated on destroy
  def generated_destroy force: false
    # @object.can.delete!

    if !force && @object.respond_to?(:is_deleted)
      @object.update is_deleted: true

      message 'Object deleted (exists in trashcan)'
    else
      @object.destroy
      message '%s deleted' % display_name
    end

    true
  end

  def generated_undelete
    error "Object not found" unless @object
    can? :create, @object

    if @object.respond_to?(:is_deleted)
      @object.update is_deleted: false
    else
      error "No is_deleted field, can't undelete"
    end

    response.message = 'Object raised from the dead.'
  end
end
