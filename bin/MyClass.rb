require "socket"
require "ipaddr"
require "json"
require "byebug"

MULTICAST_ADDR = "224.0.0.1"
BIND_ADDR = "0.0.0.0"
PORT = 3000

class MyClass

	include GladeGUI

	def before_show()
		@builder['window2'].show
    @list_view = VR::ListView.new({:name => String})
    @builder['participants_list'].add(@list_view)

		at_exit do
			e = Logout.new
			e.name = @name
			send(e.to_json)
		end

    t = Thread.new do
      socket = UDPSocket.new
		  membership = IPAddr.new(MULTICAST_ADDR).hton + IPAddr.new(BIND_ADDR).hton

		  socket.setsockopt(:IPPROTO_IP, :IP_ADD_MEMBERSHIP, membership)
		  socket.setsockopt(:SOL_SOCKET, :SO_REUSEPORT, 1)

		  socket.bind(BIND_ADDR, PORT)

      loop do
        sleep(5)
        to_remove = nil
        @list_view.each_row do |row|
          begin
            raise "Empty" unless !row.get_value(0).empty?
            q = Question.new
            q.name = row.get_value(0)
						q.token = Random.new.seed
            send(q.to_json)
            puts "Waiting response"
            message = ""
            (Timeout.timeout(1000) {
							loop do
								message, _ = socket.recvfrom(255)
								puts "Receive response"
            		message = JSON.parse(message)
            		if message['type'] == 'answer' and message['token'] == q.token
              		a = Answer.from_json(message)
              		puts "Response ok for " + a.name
									break
            		end
							end
						})

          rescue
            puts("Recv timed out for participant " + row.get_value(0))
            if !row.get_value(0).empty? and row.get_value(0) != @name
          		#@list_view.model.remove row
            end
          end
        end
      end
    end
    t.abort_on_exception = true

		t2 = Thread.new do
			puts "Created new thread"
		  socket = UDPSocket.new
		  membership = IPAddr.new(MULTICAST_ADDR).hton + IPAddr.new(BIND_ADDR).hton

		  socket.setsockopt(:IPPROTO_IP, :IP_ADD_MEMBERSHIP, membership)
		  socket.setsockopt(:SOL_SOCKET, :SO_REUSEPORT, 1)

		  socket.bind(BIND_ADDR, PORT)

		  loop do
					puts "Waiting message"
		      message, _ = socket.recvfrom(255)
					message = JSON.parse(message)
					case message['type']
					when 'private'
						p = PrivateMessage.from_json(message)
						if p.target == @name
		     			@builder['private_text_view'].buffer.insert_at_cursor("\r\nFrom: " + p.name + "\r\n" + p.message)
						end
					when 'message'
						m = Message.from_json(message)
		     		@builder['messages_text_view'].buffer.insert_at_cursor("\r\nFrom: " + m.name + "\r\n" + m.message)
          when 'participant'
            p = Participant.from_json(message)
            register_participant(p)
					when 'logout'
            l = Logout.from_json(message)
        		@list_view.each_row do |row|
							if !row.get_value(0).empty? and row.get_value(0) != @name and row.get_value(0) == l.name
          			@list_view.model.remove row
            	end
						end
						puts "Logout for " + l.name
          when 'question'
						puts "Question!!!"
            q = Question.from_json(message)
            puts @name
            if !@name.nil? and !@name.empty? and q.name == @name
              a = Answer.new
              a.name = @name
							a.token = q.token
              send(a.to_json)
            else
              if !@name.nil? and !@name.empty?
                p = Participant.new
                p.name = @name
                send(p.to_json)
              end
            end
					else
						puts 'Invalid type message'
					end
	 		end
		end
    t2.abort_on_exception = true
	end

  def register_participant participant
    flag = true
    @list_view.each_row do |row|
      if row.get_value(0) == participant.name
        puts "Participant already exist."
        flag = false
      end
    end
    if flag
      puts "Should add"
      @list_view.add_row({:name => participant.name})
    end
  end

	def welcome_message
		@builder['messages_text_view'].buffer.insert_at_cursor("Welcome " + @name + "!")
	end

	def enter_name_button__clicked(*args)
		@name = @builder['my_name_input'].text
    p = Participant.new
    p.name = @name
    send(p.to_json)
		welcome_message
		@builder['window2'].destroy
	end

	def panic_button__clicked(*args)
		destroy_window()
	end

	def send_button__clicked(*args)
		message = @builder["new_message_text_view"].text
		m = Message.new
		m.message = message
		m.name = @name
    send(m.to_json)
	end

	def private_send_button__clicked(*args)
		byebug
		message = @builder["private_message_input"].text
		m = PrivateMessage.new
		m.message = message
		m.target = @list_view.selection.selected.get_value(0)
		m.name = @name
    send(m.to_json)
	end

  def send data
    socket = UDPSocket.open
		socket.setsockopt(:IPPROTO_IP, :IP_MULTICAST_TTL, 1)
		socket.send(data, 0, MULTICAST_ADDR, PORT)
		socket.close
  end

end

class Message

	attr_accessor :name, :message

	def self.from_json data
		_self = self.new
		_self.name = data['name']
		_self.message = data['message']
		_self
	end

	def to_json
		{
			'type' => 'message',
			'name' => @name,
			'message' => @message
		}.to_json
	end
end

class PrivateMessage

	attr_accessor :name, :message, :target

	def self.from_json data
		_self = self.new
		_self.name = data['name']
		_self.message = data['message']
		_self.target = data['target']
		_self
	end

	def to_json
		{
			'type' => 'private',
			'name' => @name,
			'target' => @target,
			'message' => @message
		}.to_json
	end
end

class Participant

  attr_accessor :name

  def self.from_json data
    _self = self.new
    _self.name = data['name']
    _self
  end

  def to_json
    {'type' => 'participant', 'name' => self.name}.to_json
  end

end

class Question

  attr_accessor :name, :token

  def self.from_json data
    _self = self.new
    _self.name = data['name']
		_self.token = data['token']
    _self
  end

  def to_json
    {'type' => 'question', 'name' => self.name, 'token' => self.token}.to_json
  end

end

class Logout

  attr_accessor :name

  def self.from_json data
    _self = self.new
    _self.name = data['name']
    _self
  end

  def to_json
    {'type' => 'logout', 'name' => self.name}.to_json
  end

end

class Answer

  attr_accessor :name, :token

  def self.from_json data
    _self = self.new
    _self.name = data['name']
		_self.token = data['token']
    _self
  end

  def to_json
    {'type' => 'answer', 'name' => self.name, 'token' => self.token}.to_json
  end

end
