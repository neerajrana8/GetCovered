require 'ruby-prof'
RubyProf.start
json.array! @users, partial: 'v2/shared/users/index_partial.json.jbuilder', as: :user
result = RubyProf.stop
printer = RubyProf::CallStackPrinter.new(result)
printer.print(File.new("profile2.html", 'wb'))
