require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  session[:error] ||= []
  session[:success] ||= []
  session[:lists] ||= []
end

helpers do
  def list_complete?(list)
    list[:todos].all? { |todo| todo[:completed] == true } && num_todos_done(list) > 0
  end

  def num_todos_done(list)
    list[:todos].count { |todo| todo[:completed] == true }
  end

  def list_class(list)
    return "complete" if list_complete?(list)
  end

  def sorted_lists_with_index(lists, &block)
    combined_lists = []
    lists.each_with_index do |list, idx|
      combined_lists << [list, idx]
    end
    combined_lists.sort_by { |list, idx| list_complete?(list) ? 1 : 0 }.each(&block)
  end

  def sorted_todos_with_index(todos, &block)
    combined_todos = []
    todos.each_with_index do |todo, idx|
      combined_todos << [todo, idx]
    end
    combined_todos.sort_by { |todo, idx| todo[:completed] ? 1 : 0 }.each(&block)
  end
end


get "/" do
  redirect "/lists"
end

get "/lists" do
  @lists = session[:lists]
  erb :lists
end

get "/lists/new" do
  erb :new_list
end

get "/lists/:id" do
  @list = session[:lists][params[:id].to_i]
  erb :show_list
end

get "/lists/:id/edit" do
  @list = session[:lists][params[:id].to_i]
  erb :edit_list
end

post "/lists" do
  list_name = params[:list_name].strip
  errors = error_messages(list_name)
  if errors.empty?
    session[:lists] << { name: params[:list_name], todos: [] }
    session[:success] << "Your list was successfully created."
    redirect "/lists"
  else
    session[:error] = errors
    erb :new_list
  end
end

post "/lists/:id" do
  id = params[:id].to_i
  @list = session[:lists][id]
  list_name = params[:list_name].strip
  errors = error_messages(list_name)
  if errors.empty?
    @list[:name] = list_name
    session[:success] << "Your list name was successfully updated."
    redirect "/lists/#{id}"
  else
    session[:error] = errors
    erb :edit_list
  end
end

post "/lists/:id/delete" do
  id = params[:id].to_i
  list_name = session[:lists][id][:name]
  if session[:lists].delete_at(id)
    session[:success] << "The list \"#{list_name}\" was successfully deleted."
    redirect "/lists"
  else
    session[:error] << "The list could not be deleted."
    erb :edit_list
  end
end

post "/lists/:id/todo" do
  id = params[:id].to_i
  todo = { body: params[:todo].strip, completed: false }
  @list = session[:lists][id]
  errors = error_messages_todo(todo[:body])
  if errors.empty?
    @list[:todos] << todo
    session[:success] << "The todo was successfully added."
    redirect "/lists/#{id}"
  else
    session[:error] = errors
    erb :show_list
  end
end

post "/lists/:id/delete_todo/:todo_id" do
  id = params[:id].to_i
  todo_id = params[:todo_id].to_i
  @list = session[:lists][id]
  if @list[:todos].delete_at(todo_id)
    session[:success] << "The todo was successfully deleted."
    redirect "/lists/#{id}"
  else
    session[:error] << "The todo could not be deleted."
    erb :show_list
  end
end

post "/lists/:id/check_todo/:todo_id" do
  id = params[:id].to_i
  todo_id = params[:todo_id].to_i
  @list = session[:lists][id]
  @list[:todos][todo_id][:completed] = params[:completed] == "true"
  redirect "/lists/#{id}"
end

post "/lists/:id/check_all" do
  id = params[:id].to_i
  @list = session[:lists][id]
  @list[:todos].each do |todo|
    todo[:completed] = true
  end
  session[:success] << "All items have been completed."
  redirect "/lists/#{id}"
end

def error_messages(name)
  errors = []
  unless (1..100).cover?(name.size)
    errors << "Your list name must be between 1 and 100 characters."
  end
  if session[:lists].any? { |list| name == list[:name] }
    errors << "Your list name must be unique."
  end
  errors
end

def error_messages_todo(new_todo)
  errors = []
  unless (1..200).cover?(new_todo.size)
    errors << "Your todo must be between 1 and 200 characters."
  end
  if @list[:todos].any? { |todo| todo[:body] == new_todo }
    errors << "Your todo must be unique."
  end
  errors
end