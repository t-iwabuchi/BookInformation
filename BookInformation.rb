require 'sinatra'
require 'sqlite3'

#データベースの準備
before do
	@db = SQLite3::Database.new("BookInformation")
end
after do
	@db.close
end

#メインページ
get '/' do
	erb :index ,layout: :layout
end

#閲覧ページ
get '/browse/:ISBN' do
	erb :browse ,layout: :layout
end

#登録ページ
get '/registration' do
	erb :registration ,layout: :layout
end

#登録作業
get '/registration/insert' do
	@isbn = params["isbn"]
	@bookTitle = params["title"]
	@bookAuthor = params["author"]
	@bookPublisher = params["publisher"]
	@publication_year = params["publication_year"]
	@publication_month = params["publication_month"]
	@publication_date = params["publication_date"]

	if(@isbn==NULL||@title==NULL){
		redirect '/registration'
	}

	sql = <<-SQL
	  INSERT INTO BookInformation(isbn,title,author,publisher,publication_year,publication_month,publication_date)
	  VALUES("#{@isbn}","#{@title}","#{@author}","#{@publisher}","#{@publication_year}","#{@publication_month}","#{@publication_date}");
	SQL
end

#アプリケーション紹介ページ
get '/about' do
	erb :about ,layout: :layout
end