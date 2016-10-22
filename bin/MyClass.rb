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
    @rooms_view = VR::ListView.new({:title => String, :participant_1 => String, :participant_2 => String})
    @builder['scrolledwindow2'].add(@rooms_view)
    @rooms = []

    at_exit do
      e = Logout.new
      e.name = @name
      send(e.to_json)

      rl = RoomLogout.new
      rl.titles = @rooms.map{|room| room.title}.to_a
      send(rl.to_json)
    end

    t = Thread.new do
      socket = UDPSocket.new
      membership = IPAddr.new(MULTICAST_ADDR).hton + IPAddr.new(BIND_ADDR).hton

      socket.setsockopt(:IPPROTO_IP, :IP_ADD_MEMBERSHIP, membership)
      socket.setsockopt(:SOL_SOCKET, :SO_REUSEPORT, 1)

      socket.bind(BIND_ADDR, PORT)

      loop do
        sleep(5)
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
        when 'rooms_logout'
          rl = RoomLogout.from_json(message)
          remove_rooms(rl)
        when 'room'
          r = Room.from_json(message)
          add_room(r)
        when 'participant'
          p = Participant.from_json(message)
          register_participant(p)
        when 'join'
          j = JoinRoom.from_json(message)
          join_room(j)
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

  def remove_rooms rl
    @rooms_view.each_row do |row|
      if rl.rooms.include? row.get_value(0)
        @rooms_view.model.remove_row row
      end
    end
  end

  def join_room join
    @rooms_view.each_row do |row|
      if row.get_value(0) == join.title and row.get_value(0) != @name
        row[:participant_2] = join.participant
      end
    end
  end

  def join_button__clicked(*args)
    title = @rooms_view.selection.selected.get_value(0)
    j = JoinRoom.new
    j.title = title
    j.participant = @name
    send(j.to_json)
  end

  def add_room room
    flag = true
    @rooms_view.each_row do |row|
      if row.get_value(0) == room.title
        puts "Room already exist."
        flag = false
      end
    end
    if flag
      puts "Should add"
      @rooms_view.add_row(
        {
          :title => room.title,
          :participant_1 => room.participant_1,
          :participant_2 => room.participant_2
        }
      )
    end
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

  def create_room_button__clicked(*args)
    r = Room.new
    r.title = @builder['title_input'].text
    r.participant_1 = @name
    @rooms << r
    send(r.to_json)
  end

  def destroy_window

  end

  def panic_button__clicked(*args)
    window1__destroy(*args)
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

class JoinRoom
  attr_accessor :title, :participant

  def self.from_json data
    _self = self.new
    _self.title = data['title']
    _self.participant = data['participant']
    _self
  end

  def to_json
    {
      'type' => 'join',
      'title' => self.title,
      'participant' => self.participant
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

class Room
  attr_accessor :title, :participant_1, :participant_2

  def self.from_json data
    _self = self.new
    _self.title = data['title']
    _self.participant_1 = data['participant_1']
    _self.participant_2 = data['participant_2']
    _self
  end

  def to_json
    {
      'type' => 'room',
      'title' => self.title,
      'participant_1' => self.participant_1,
      'participant_2' => self.participant_2
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

class RoomLogout
  attr_accessor :titles

  def self.from_json data
    _self = self.new
    _self.titles = data['titles']
    _self
  end

  def to_json
    byebug
    {'type' => 'rooms_logout', 'rooms' => self.titles.map{|r| {'title' => r}}}.to_json
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
