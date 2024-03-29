class CompanyApi < ModelApi
  icon '<path d="M21,7h-6c-0.553,0-1,0.447-1,1v3h-2V4c0-0.553-0.447-1-1-1H3C2.447,3,2,3.447,2,4v16c0,0.553,0.447,1,1,1h7h1h4h1h5  c0.553,0,1-0.447,1-1V8C22,7.447,21.553,7,21,7z M8,6h2v2H8V6z M6,16H4v-2h2V16z M6,12H4v-2h2V12z M6,8H4V6h2V8z M10,16H8v-2h2V16z M10,12H8v-2h2v1V12z M19,16h-2v-2h2V16z M19,12h-2v-2h2V12z"/>'

  documented

  collection do
    params do
      country_id  Integer
      is_active   false
    end
    allow :put
    desc 'List of available companies'
    def index
      message 'done'
    end

    def info
      { countries_in_index: 123 }
    end
  end

  member do
    desc 'Simple index'
    params do
      set      :is_active, false
      country?
    end
    def index
      message 'all ok'
      @model.name
    end

    def show
      @model.name
    end

    params do
      company model: :company
    end
    def update
      params.company.to_h
    end

    define :foo do
      params do
        bar Integer
      end

      proc do
        params.bar * 3
      end
    end
  end

  def index
    123
  end
end

