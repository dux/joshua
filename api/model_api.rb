class ModelApi < ApplicationApi
  collection do
    def call_me_in_child
      @number = 2345
    end
  end

  member do
    before do
      id = @api.id.to_s == @api.id.to_i.to_s ? @api.id.to_i : nil

      if id == 1
        @model = Company.new
      else
        error 'Model not found'
      end
    end

    desc 'Show object creator'
    desc 'Even more description'
    params do
      show_all false
    end
    def creator
      '@dux'
    end

    desc 'Update the model'
    def update
      'updated'
    end

    def call_me_in_child
      @number = 1234
    end
  end
end