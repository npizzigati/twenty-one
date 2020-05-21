class Display
  # ANSI escape codes
  # Properties
  MESSAGE_COLOR = "\u001b[40m" # black
  WARNING_COLOR = "\u001b[36m" # cyan
  MONEY_COLOR = "\u001b[36m" # cyan
  HIGHLIGHT = "\e[1m"
  ALL_PROPERTIES_OFF = "\e[0m"
  # Other
  CTRL_C = "\u0003"

  # Other escape codes
  CARRIAGE_RETURN = "\r"
  LINE_FEED = "\n"

  # Positions
  TITLE_START = [1, 1]
  CHIPS_START = [1, 15]
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

  DISTANCE_BETWEEN_CARDS_IN_HAND = 3

  def initialize(terminal_setup = true)
    prepare_terminal if terminal_setup
    set_cursors
    @warning_visible = false
  end

  def prepare_terminal
    STDIN.echo = false
    hide_terminal_cursor
    clear_screen
  end

  def set_cursors
    @player_card_cursor = Cursor.new(*PLAYER_CARDS_START)
    @dealer_card_cursor = Cursor.new(*DEALER_CARDS_START)
    @title_cursor = Cursor.new(*TITLE_START)
    @chips_cursor = Cursor.new(*CHIPS_START)
    @message_cursor = Cursor.new(*MESSAGE_START)
    @player_heading_cursor = Cursor.new(*PLAYER_HEADING_START)
    @dealer_heading_cursor = Cursor.new(*DEALER_HEADING_START)
    @warning_cursor = Cursor.new(*WARNING_START)
  end

  def hide_terminal_cursor
    STDOUT.write "\e[?25l"
  end

  def show_terminal_cursor
    STDOUT.write "\e[?25h"
  end

  def welcome
    @title_cursor.print_here 'TWENTY-ONE'
    @message_cursor.print_here 'Welcome to Twenty-one. ', advance: true
    any_key_to_continue
  end

  def goodbye(money)
    if money == 0
      @message_cursor.print_here('You\'re out of money. ',
                                 advance: true)
      any_key_to_continue
    end
    @message_cursor.print_here('Thanks for playing! ' \
                                'You\'re walking away with ' \
                                "$#{money}. " \
                                'Press any key to exit.',
                                clear_line: true)
    input_char('')
  end

  def prepare_table(player_name)
    @message_cursor.clear
    print_hand_headings player_name
  end

  def clear_table
    clear_screen
    set_cursors
    @title_cursor.print_here 'TWENTY-ONE'
  end

  def print_hand_headings(player_name)
    @player_heading_cursor.print_here "#{player_name}:"
    @dealer_heading_cursor.print_here 'Dealer:'
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

  def print_card(card, klass, face_down: false)
    cursor = klass == Dealer ? @dealer_card_cursor : @player_card_cursor
    cursor.save_position

    visual_card = if face_down
                    assemble_face_down_card
                  else
                    assemble_visual_card(card.suit, card.rank)
                  end
    print_card_lines(visual_card, cursor)

    cursor.restore_saved_position
    cursor.move_right(visual_card.first.size + DISTANCE_BETWEEN_CARDS_IN_HAND)
  end

  def show_dealing_message
    @message_cursor.print_here('Dealing...', clear_line: true)
  end

  def reveal_dealer_hole_card(card)
    cursor = Cursor.new(*DEALER_CARDS_START)
    visual_card = assemble_visual_card(card.suit, card.rank)

    print_card_lines(visual_card, cursor)
  end

  def print_card_lines(visual_card, cursor)
    visual_card.each do |line|
      cursor.print_here line
      cursor.move_down(1)
    end
  end

  def echo_on(&block)
    STDIN.echo = true
    show_terminal_cursor
    block.call
  ensure
    STDIN.echo = false
    hide_terminal_cursor
  end

  def input_string(prompt, check: nil, warning: 'Invalid input')
    @message_cursor.print_here prompt, clear_line: true
    loop do
      input = gets.chomp
      if check.match?(input)
        @warning_cursor.clear if @warning_visible
        return input
      end

      print_warning warning
      @message_cursor.print_here prompt, clear_line: true
    end
  end

  def input_char(prompt, options = nil)
    @message_cursor.print_here prompt
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

  def print_player_busted
    @message_cursor.print_here('You bust! ')
  end

  def any_key_to_continue
    input_char('Press any key to continue.')
  end

  def print_player_score(player_total)
    message = "Your hand total is #{player_total}. "
    @message_cursor.print_here(message, clear_line: true,
                               advance: true)
    any_key_to_continue
  end

  def print_score_outcome(player_total, dealer_total)
    message = if player_total > 21
                'You bust! '
              elsif dealer_total > 21
                'Dealer busts. '
              else
                "You have #{player_total} and the dealer has " \
                "#{dealer_total}. "
              end
    @message_cursor.print_here(message, clear_line: true,
                               advance: true)
  end

  def print_winner(winner)
    hide_terminal_cursor
    case winner
    when :dealer
      @message_cursor.print_here('Dealer wins the hand. ', advance: true)
    when :player
      @message_cursor.print_here('You win the hand! ', advance: true)
    else
      @message_cursor.print_here('The hand is a tie! ', advance: true)
    end
  end

  def prompt_for_player_name
    message = 'Please enter your name (only word characters ' \
              'allowed, up to 10 characters): '
    name = nil
    echo_on do
      name = input_string message, check: /^[\w]{1,10}$/
    end

    name
  end

  def show_money(money)
    @chips_cursor.print_here('You have: $', clear_line: true,
                             advance: true)
    @chips_cursor.print_here(money, color: MONEY_COLOR)
  end

  def retrieve_bet(max)
    input = nil
    echo_on do
      loop do
        input = input_string("Enter your bet (dollar amount, without cents): $",
                             check: /^\d{1,3}$/,
                             warning: 'Invalid bet')
        input = input.to_i
        if input <= max && input > 0
          @warning_cursor.clear if @warning_visible
          return input
        end
        print_warning "Bet must be between 1 and #{max}"
      end
    end
  end

  def print_warning(text)
    @warning_cursor.clear if @warning_visible
    sleep 0.08
    @warning_cursor.print_here text, color: WARNING_COLOR
    @warning_visible = true
  end

  def clear_screen
    STDOUT.write "\u001b[2J" # clear screen
    STDOUT.write "\u001b[0;0H" # set cursor to home position
  end

  def continue_playing?
    input_char("Continue playing? (y/n)", %w(y n)) == 'y'
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

    def print_here(text, clear_line: false, advance: false, color: MESSAGE_COLOR)
      clear if clear_line == true
      move_to_point(*@coords)
      print_color(color) do
        print text
      end
      move_right(text.size) if advance == true
    end

    def print_color(color, &block)
      STDOUT.write color
      block.call
      STDOUT.write ALL_PROPERTIES_OFF
    end

    def clear
      @coords = @initial_coords
      move_to_point(*@coords)
      clear_to_end_of_line
    end

    def clear_to_end_of_line
      STDOUT.write "\u001b[0K"
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

    def move_right(columns)
      setpos(@coords.first, @coords.last + columns)
    end

    def move_down(rows)
      setpos(@coords.first + rows, @coords.last)
    end
  end
end
