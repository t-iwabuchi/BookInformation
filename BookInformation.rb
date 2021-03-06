Encoding.default_external = 'UTF-8'

require 'sinatra'
require 'sqlite3'
require "sinatra/reloader" if development?
#以下はGoogle Books APIを使うため
require 'net/http'  
require 'uri'  
require 'json'  
require 'open-uri'

#データベースの準備
before do
	@db = SQLite3::Database.new("BookInformation.db")
end
after do
	@db.close
end

#メインページ
get '/' do
	sql = <<-SQL
		SELECT * FROM BookData ORDER BY views desc;
	SQL
	@view_rank = @db.execute(sql)
	erb :index ,layout: :layout
end

#閲覧ページ
get '/browse/:isbn/:id' do
	@ISBN = params["isbn"].to_i
	@ID = params["id"].to_i

	#IDが指定されていなかった場合に、入力されたISBNが結び付けられている中で最後のIDを指定
	if(!@ID)
		sql = <<-SQL
			SELECT id FROM BookData WHERE isbn = "#{@ISBN}"
		SQL
		data = @db.execute(sql)
		if (data.empty?)
			redirect '/'
		end
		@ID = data[data.length-1]
	end

	#IDに結びついているISBNが入力されたISBNと等しいか確認
	sql = <<-SQL
		SELECT isbn FROM BookData WHERE id = "#{@ID}"
	SQL
	data = @db.get_first_value(sql)
	if(data!=@ISBN)
		redirect '/about'
	end

	#閲覧数更新
	sql = <<-SQL
		SELECT views FROM BookData WHERE id = "#{@ID}"
	SQL
	data = @db.get_first_value(sql)
	data = data + 1

	sql = <<-SQL
		UPDATE BookData SET views = "#{data}" WHERE id = "#{@ID}"
	SQL
	@db.execute(sql)

	#閲覧する対象のデータを取得
	sql = <<-SQL
		SELECT * FROM BookData WHERE id = "#{@ID}"
	SQL
	#id,isbnは取得済み
	#それぞれのデータは@deta配列の[0]の中の配列として入っている
	#配列の添字は0から始まる
	@data = @db.execute(sql)
	@title = @data[0][2]
	@author = @data[0][3]
	@publisher = @data[0][4]
	@publication_year = @data[0][5]
	@publication_month = @data[0][6]
	@publication_dates = @data[0][7]
	@views = @data[0][8]

	#評価を取得
	sql = <<-SQL
		SELECT * FROM BookReputation WHERE dataid = "#{@ID}"
	SQL
	@reputation = @db.execute(sql)

	#閲覧ページに移動
	erb :browse ,layout: :layout
end

#評価登録作業
get '/reputation/insert' do
	@dataid = params["id"]
	@stars = params["stars"]
	@reputation = params["reputation"]

	sql = <<-SQL
		INSERT INTO BookReputation(dataid,stars,reputation)
		VALUES ("#{@dataid}","#{@stars}","#{@reputation}")
	SQL
	@db.execute(sql)

	redirect back
end

#登録ページ
get '/registration' do
	erb :registration ,layout: :layout
end

#登録作業
get '/registration/insert' do
	@isbn = params["isbn"].to_i
	@title = params["title"]
	@author = params["author"]
	@publisher = params["publisher"]
	@publication_year = params["publication_year"].to_i
	@publication_month = params["publication_month"].to_i
	@publication_date = params["publication_date"].to_i

	if (@isbn && @title)
		sql = <<-SQL
	  		INSERT INTO BookData(isbn,title,author,publisher,publication_year,publication_month,publication_date)
	  		VALUES("#{@isbn}","#{@title}","#{@author}","#{@publisher}","#{@publication_year}","#{@publication_month}","#{@publication_date}");
		SQL
		@db.execute(sql)

		#idの取得
		sql = <<-SQL
			SELECT id FROM BookData WHERE ROWID = last_insert_rowid();
		SQL
		@id = @db.get_first_value(sql);
		redirect "/browse/#{@isbn}/#{@id}"
	else
		redirect '/registration'
	end
end

#検索結果ページ
get '/search' do
	# 文字・数値の判別
	def integer_string?(str)
  		Integer(str)
  		true
	rescue ArgumentError
  		false
	end

	#本情報の中から調べる
	#文字として調べる
	@search_text = params["search"]
	sql = <<-SQL
		SELECT * FROM BookData WHERE title LIKE "%#{@search_text}%" OR author LIKE "%#{@search_text}%" OR publisher LIKE "%#{@search_text}%"
	SQL
	@data1=@db.execute(sql);
	#本評価の中から調べる
	#評価をパターンマッチング
	sql = <<-SQL
		SELECT * FROM BookReputation WHERE reputation LIKE "%#{@search_text}%"
	SQL
	@data2=@db.execute(sql)
	#評価しかない（他にもあるが）ので書名も追加
	@data2.each do |row|
		sql = <<-SQL
			SELECT title FROM BookData WHERE id = "#{row[1]}"
		SQL
		title = @db.get_first_value(sql)
		row.push(title)
	end

	#数字として調べる
	if integer_string?(@search_text)
		@search_number = @search.to_i
		sql = <<-SQL
			SELECT * FROM BookData WHERE isbn="#{@search_number}" OR publication_year="#{@search_number}" OR publication_month="#{@search_number}" OR publication_date="#{@search_number}"
		SQL
		@data3=@db.execute(sql)
	end

	#Google Books APIから検索
	begin
		@googlesdata = JSON.parse(open("https://www.googleapis.com/books/v1/volumes?q=#{@search_text.encode("Shift_JIS")}&country=JP").read,quirks_mode: true)
	rescue
		@googlesdata = Hash.new
		@googlesdata.store("errorMessage","データを取得できません")
	end

	erb :search, layout: :layout
end

#アプリケーション紹介ページ
get '/about' do
	erb :about ,layout: :layout
end

#404(ページが見つからない)対策
not_found do
	erb :not_found, layout: :layout
end
