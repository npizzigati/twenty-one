require 'io/console'
require 'pry'

SUITS = [:hearts, :spades, :clubs, :diamonds]
RANKS = ('2'..'10').to_a + %w(J Q K A)

class Participant
  attr_accessor :total
  attr_reader :name

  def initialize(display) # No display for testing
    @hand = []
    @total = 0
    @display = display
    @name = retrieve_name
  end

  def <<(card)
    @hand << card
    update_total
    @display.print_card(card, @name, @hand.size)
  end

  def update_total
    scores = @hand.map { |card| card.soft_value }
    index = 0
    num_of_scores = scores.size
    # Give aces hard value where appropriate
    while scores.sum > 21 && index < num_of_scores
      scores[index] = 1 if scores[index] == 11
      index += 1
    end

    @total = scores.sum
  end

  def bust?
    @total > 21
  end

  def twenty_one?
    @total == 21
  end
end

class Player < Participant
  attr_accessor :bet, :money

  def initialize(display)
    super
    @money = 20
    @bet = nil
  end

  def retrieve_name
    'Guy'
  end

  def hit?
    return false if @total > 20
    @display.input_char('Press h to hit or s to stand', %w(h s)) == 'h'
  end
end

class Dealer < Participant
  def initialize(display)
    super
    @deck = Deck.new
    @deck.shuffle!
  end

  def deal(num_of_cards, recipient = self)
    # delay of 1 second between cards dealt to dealer when hitting
    sleep 1 if num_of_cards == 1 && recipient == self

    num_of_cards.times do
      card = @deck.pop
      recipient << card
    end
  end

  def retrieve_name
    'Dealer'
  end

  def hit?
    @total < 17
  end

  def reveal_hole_card
    @display.reveal_dealer_hole_card(@hand.first)
  end
end

class Card
  attr_reader :suit, :rank

  def initialize(suit, rank)
    @suit = suit
    @rank = rank
  end

  def soft_value
    case @rank
    when ('1'..'9')
      @rank.to_i
    when 'A'
      11
    else
      10
    end
  end
end

class Deck
  def initialize
    create_deck
  end

  def create_deck
    @cards = []
    RANKS.each do |rank|
      SUITS.each do |suit|
        @cards << Card.new(suit, rank)
      end
    end
  end

  def pop
    @cards.pop
  end

  def shuffle!
    @cards.shuffle!
  end
end

class Display
  # ANSI escape codes
  # Properties
  MESSAGE_COLOR = "\u001b[40m" # cyan
  WARNING_COLOR = "\u001b[36m" # cyan
  SCORE_COLOR = "\u001b[36m" # cyan
  HIGHLIGHT = "\e[1m"
  ALL_PROPERTIES_OFF = "\e[0m"
  # Other
  CTRL_C = "\u0003"

  # Other escape codes
  CARRIAGE_RETURN = "\r"
  LINE_FEED = "\n"

  # Positions
  TITLE_START = [1, 1]
  MESSAGE_START = [2, 1]
  WARNING_START = [3, 1]
  PLAYER_CARDS_START = [5, 5]
  PLAYER_HEADING_START = [4, 5]
  DEALER_CARDS_START = [16, 5]
  DEALER_HEADING_START = [15, 5]

  SUIT_SYMBOLS = { spades: '♠', clubs: '♣', hearts: '♥', diamonds: '♦' }

  BLANK_CARD = [
    '┌─────────┐',
    '│         │',
    '│         │',
    '│         │',
    '│         │',
    '│         │',
    '│         │',
    '│         │',
    '└─────────┘'
  ]

  # Blank card pattern
  MEDIUM_SHADE = "\u2592"

  #Coordinates of suit symbols and rank numbers on visual card
  SUIT_COORDS = [[2, 1], [4, 5], [6, 9]]
  RANK_COORDS = [[1, 1], [7, 9]]

  CARD_FADE_IN_DELAY = 0.03
  DISTANCE_BETWEEN_CARDS_IN_HAND = 3

  def initialize(terminal_setup = true)
    prepare_terminal if terminal_setup
    @player_card_cursor = Cursor.new(*PLAYER_CARDS_START)
    @dealer_card_cursor = Cursor.new(*DEALER_CARDS_START)
    @title_cursor = Cursor.new(*TITLE_START)
    @message_cursor = Cursor.new(*MESSAGE_START)
    @player_heading_cursor = Cursor.new(*PLAYER_HEADING_START)
    @dealer_heading_cursor = Cursor.new(*DEALER_HEADING_START)
    @warning_cursor = Cursor.new(*WARNING_START)
    @warning_visible = false
  end

  def prepare_terminal
    STDIN.echo = false
    hide_terminal_cursor
    clear_screen
  end

  def hide_terminal_cursor
    STDOUT.write "\e[?25l"
  end

  def show_terminal_cursor
    STDOUT.write "\e[?25h"
  end

  def welcome
    @title_cursor.print_here 'TWENTY-ONE', :no_advance
    @message_cursor.print_here 'Welcome to Twenty-one. ', :advance
    input_char 'Press any key to start.'
  end

  def goodbye
    input_char ''
  end

  def prepare_table
    @message_cursor.clear
    print_hand_headings
  end

  def print_hand_headings
    @player_heading_cursor.print_here 'You:', :no_advance
    @dealer_heading_cursor.print_here 'Dealer:', :no_advance
  end

  def clear_message_line
    @message_cursor.clear
  end

  def assemble_visual_card(suit, rank)
    visual_card = blank_card_copy
    SUIT_COORDS.each do |coord_pair|
      visual_card[coord_pair.first][coord_pair.last] = SUIT_SYMBOLS[suit]
    end
    RANK_COORDS.each do |coord_pair|
      visual_card[coord_pair.first][coord_pair.last] = rank
      # Remove extra space in card line if rank is 10 to avoid wrecking format
      visual_card[coord_pair.first].sub!(/\s{2}/, ' ') if rank == '10'
    end
    visual_card
  end

  def assemble_face_down_card
    visual_card = blank_card_copy
    visual_card.map do |line|
      line.gsub(/\s/, MEDIUM_SHADE)
    end
  end

  def blank_card_copy
    BLANK_CARD.map(&:dup)
  end

  def print_card(card, name, cards_in_hand)
    cursor = name == 'Dealer' ? @dealer_card_cursor : @player_card_cursor
    cursor.save_position
    if cards_in_hand == 1 && name == 'Dealer'
      visual_card = assemble_face_down_card
    else
      visual_card = assemble_visual_card(card.suit, card.rank)
    end

    print_card_lines(visual_card, cursor)

    cursor.restore_saved_position
    cursor.move_right(visual_card.first.size + DISTANCE_BETWEEN_CARDS_IN_HAND)
  end

  def reveal_dealer_hole_card(card)
    cursor = Cursor.new(*DEALER_CARDS_START)
    visual_card = assemble_visual_card(card.suit, card.rank)

    print_card_lines(visual_card, cursor)
  end

  def print_card_lines(visual_card, cursor)
    visual_card.each do |line|
      cursor.print_here line, :no_advance
      cursor.move_down(1)
      sleep CARD_FADE_IN_DELAY
    end
  end

  def echo_on(&block)
    STDIN.echo = true
    show_terminal_cursor

    block.call

    STDIN.echo = false
    hide_terminal_cursor
  end

  def input_string(prompt, valid_regex)
    @message_cursor.print_here prompt, :no_advance
    loop do
      input = gets.chomp
      if valid_regex.match(input)
        @warning_cursor.clear if @warning_visible
        return input.to_i
      end

      print_warning 'Invalid input'
    end
  end

  def input_char(prompt, options = nil)
    @message_cursor.print_here prompt, :no_advance
    loop do
      input = STDIN.getch.downcase
      exit(1) if input == CTRL_C

      if !options || options.include?(input)
        @warning_cursor.clear if @warning_visible
        return input
      end

      print_warning "Please enter #{joiner(options)}"
    end
  end

  def joiner(options)
    options = options.map { |option| option == ' ' ? 'space' : option }
    case options.size
    when 1
      options[0]
    when 2
      "#{options[0]} or #{options[1]}"
    when 3..10
      options[0..-2].join(', ') + ' or ' + options[-1]
    end
  end

  def print_outcome(winner, busted)
    # Should print message with player totals if no bust.
    if busted
      @message_cursor.print_here "#{busted} busts. ", :advance
    end
    case winner
    when :dealer then @message_cursor.print_here "Dealer wins round!", :no_advance
    when :player then @message_cursor.print_here "You win the round!", :no_advance
    else
      @message_cursor.print_here "The round was a tie!", :no_advance
    end
  end

  def show_player_money(money)
    @message_cursor.clear
    @message_cursor.print_here "You have $#{money} in chips. ", :advance
  end

  def retrieve_bet
    echo_on do
      input_string "Enter your bet (must be a whole number): ", /\d{1,3}/
    end
  end

  def print_warning(text)
    @warning_cursor.clear if @warning_visible
    sleep 0.08
    @warning_cursor.print_here text, :no_advance, WARNING_COLOR
    @warning_visible = true
  end

  def clear_screen
    STDOUT.write "\u001b[2J" # clear screen
    STDOUT.write "\u001b[0;0H" # set cursor to home position
  end

  def close
    STDIN.echo = true
    show_terminal_cursor
    clear_screen
  end

  class Cursor
    def initialize(y, x)
      @coords = [y, x]
      @initial_coords = @coords
      @saved_position = []
    end

    def save_position
      @saved_position = @coords
    end

    def print_here(text, move_cursor, color = MESSAGE_COLOR)
      move_to_point(*@coords)
      STDOUT.write color
      print text
      STDOUT.write ALL_PROPERTIES_OFF
      move_right(text.size) if move_cursor == :advance
    end

    def clear
      @coords = @initial_coords
      move_to_point(*@coords)
      clear_to_end_of_line
    end

    def clear_to_end_of_line
      STDOUT.write "\u001b[2K"
    end

    def restore_saved_position
      @coords = @saved_position
    end

    def setpos(y_coord, x_coord)
      @coords = [y_coord, x_coord]
    end

    def move_to_point(y_coord, x_coord)
      STDOUT.write "\u001b[#{y_coord};#{x_coord}H"
    end

    def y
      @coords.first
    end

    def x
      @coords.last
    end

    def move_right(columns)
      setpos(@coords.first, @coords.last + columns)
    end

    def move_left(columns)
      setpos(@coords.first, @coords.last - columns)
    end

    def move_down(rows)
      setpos(@coords.first + rows, @coords.last)
    end

    def move_up(rows)
      setpos(@coords.first - rows, @coords.last)
    end
  end
end

class TwentyOneGame
  def initialize
    @display = Display.new
    @dealer = Dealer.new(@display)
    @player = Player.new(@display)
    @busted = nil
  end

  def play_sitting
    @display.welcome
    play_round
    @busted = nil
    @round_winner = nil
    @display.goodbye
  end

  def play_round
    @display.show_player_money(@player.money)
    @player.bet = @display.retrieve_bet
    @display.prepare_table
    deal_initial_cards

    process_player_turn
    @dealer.reveal_hole_card
    process_dealer_turn unless @player.bust?
    process_outcome
  end

  def process_player_turn
    while @player.hit?
      process_hit(@player)
    end
  end

  def process_dealer_turn
    process_hit(@dealer) while @dealer.hit? unless @player.bust?
  end

  def process_outcome
    process_bust
    if @player.total > @dealer.total
      @round_winner = :player
      @player.money += @player.bet
    elsif @dealer.total > @player.total
      @round_winner = :dealer
      @player.money -= @player.bet
    end
    @display.print_outcome(@round_winner, @busted)
  end

  def process_bust
    [@player, @dealer].each do |person|
      if person.bust?
        person.total = 0
        @busted = person.name
      end
    end
  end

  def process_hit(person)
    @display.clear_message_line
    @dealer.deal(1, person)
  end

  def deal_initial_cards
    @dealer.deal(2, @player)
    @dealer.deal(2, @dealer)
  end

  def close_display
    @display.close
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    game = TwentyOneGame.new
    game.play_sitting
  ensure
    game.close_display
  end
end
