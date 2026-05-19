class TodoApi < ApplicationApi
  documented
  class_desc 'Todo items'
  icon 'task_alt'

  TODOS ||= [
    { id: 1, text: 'first thing',  done: true  },
    { id: 2, text: 'second thing', done: false },
    { id: 3, text: 'third thing',  done: false }
  ]

  desc 'List all todos'
  allow :get
  def list
    TODOS
  end

  desc 'Create a new todo'
  params do
    text String, required: true
    done false
  end
  def create
    new_id = (TODOS.map { |t| t[:id] }.max || 0) + 1
    item   = { id: new_id, text: params.text, done: params.done }
    TODOS.push item
    item
  end

  ref do
    before do
      @item = TODOS.find { |t| t[:id] == @ref.to_i }
      error :not_found unless @item
    end

    desc 'Get one todo by id'
    allow :get
    def show
      @item
    end

    desc 'Toggle done flag'
    def toggle
      @item[:done] = !@item[:done]
      @item
    end

    desc 'Delete a todo'
    allow :delete
    def destroy
      TODOS.delete_if { |t| t[:id] == @item[:id] }
      { deleted: @item[:id] }
    end
  end
end
