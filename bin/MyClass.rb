require "socket"
require "ipaddr"
require "json"

MULTICAST_ADDR = "224.0.0.1"
BIND_ADDR = "0.0.0.0"
PORT = 3000

class MyClass

	include GladeGUI

	def before_show()
		@builder['window2'].show
		
		Thread.new do
			puts "Created new thread"
		  socket = UDPSocket.new
		  membership = IPAddr.new(MULTICAST_ADDR).hton + IPAddr.new(BIND_ADDR).hton

		  socket.setsockopt(:IPPROTO_IP, :IP_ADD_MEMBERSHIP, membership)
		  socket.setsockopt(:SOL_SOCKET, :SO_REUSEPORT, 1)

		  socket.bind(BIND_ADDR, PORT)

		  loop do
					puts "Waiting message"
		      message, _ = socket.recvfrom(255)
					m = Message.from_json(message)
		      @builder['messages_text_view'].buffer.insert_at_cursor("\r\nFrom: " + m.name + "\r\n" + m.message)
	 		end
		end
	end

	def welcome_message
		@builder['messages_text_view'].buffer.insert_at_cursor("Welcome " + @name + "!")
	end

	def enter_name_button__clicked(*args)
		@name = @builder['my_name_input'].text
		welcome_message
		@builder['window2'].destroy
	end

	def panic_button__clicked(*args)
		destroy_window()
	end

	def send_button__clicked(*args)
		socket = UDPSocket.open
		socket.setsockopt(:IPPROTO_IP, :IP_MULTICAST_TTL, 1)
		message = @builder["new_message_text_view"].text
		m = Message.new
		m.message = message
		m.name = @name
		socket.send(m.to_json, 0, MULTICAST_ADDR, PORT)
		socket.close
	end

end

class Message

	attr_accessor :name, :message

	def self.from_json string
		data = JSON.parse string
		_self = self.new
		_self.name = data['name']
		_self.message = data['message']
		_self
	end

	def to_json
		{'name' => @name, 'message' => @message}.to_json
	end
end
