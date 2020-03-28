class Company
  def name
    'JRNI'
  end
end

class ModelApi < ApplicationApi
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
    params.show_all false
    def creator
      '@dux'
    end

    desc 'Update the model'
    def update
      'updated'
    end
  end
end