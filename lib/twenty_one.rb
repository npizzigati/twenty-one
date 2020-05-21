require 'io/console'
require_relative 'display.rb'

SUITS = [:hearts, :spades, :clubs, :diamonds]
RANKS = ('2'..'10').to_a + %w(J Q K A)
DEALING_DELAY = 0.6
STARTING_PLAYER_MONEY = 20
DEALER_STAY_VALUE = 17
ACE_SOFT_VALUE = 11
ACE_HARD_VALUE = 1
FACE_CARD_VALUE = 10
CARD_MAXIMUM = 21

class Participant
  attr_accessor :total, :name

  def initialize(display)
    @hand = []
    @total = 0
    @display = display
  end

  def <<(card)
    klass = self.class

    @hand << card
    update_total

    if @hand.size == 1 && klass == Dealer
      @display.print_card(card, klass, face_down: true)
    else
      @display.print_card(card, klass)
    end
  end

  def update_total
    scores = @hand.map(&:soft_value)
    index = 0
    num_of_scores = scores.size

    while scores.sum > CARD_MAXIMUM && index < num_of_scores
      scores[index] = ACE_HARD_VALUE if scores[index] == ACE_SOFT_VALUE
      index += 1
    end

    @total = scores.sum
  end

  def clear_hand
    @hand = []
    @total = 0
  end

  def busted?
    @total > CARD_MAXIMUM
  end
end

class Player < Participant
  attr_accessor :bet, :money

  def initialize(display)
    super
    @money = STARTING_PLAYER_MONEY
    @bet = nil
    @name = retrieve_name
  end

  def retrieve_name
    @display.prompt_for_player_name
  end

  def hit?
    return false if @total >= CARD_MAXIMUM

    @display.input_char('Press h to hit or s to stand', %w(h s)) == 'h'
  end
end

class Dealer < Participant
  def initialize(display)
    super
    @deck = Deck.new
    shuffle_deck
    @name = 'Dealer'
  end

  def deal(recipient)
    @display.show_dealing_message
    card = @deck.pop
    sleep DEALING_DELAY
    recipient << card
  end

  def hit?
    @total < DEALER_STAY_VALUE
  end

  def shuffle_deck
    @deck.shuffle!
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
    when ('1'..'10')
      @rank.to_i
    when 'A'
      ACE_SOFT_VALUE
    else
      FACE_CARD_VALUE
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

class TwentyOneGame
  def initialize
    @display = Display.new
  end

  def play_sitting
    @display.welcome
    @dealer = Dealer.new(@display)
    @player = Player.new(@display)
    loop do
      prepare_round
      play_round
      break if @player.money == 0 || stop_playing?

      reset_table
    end

    @display.goodbye(@player.money)
  end

  def stop_playing?
    !@display.continue_playing?
  end

  def play_round
    @dealer.deal(@player) while @player.hit?
    @dealer.reveal_hole_card
    unless player.busted?
      @dealer.deal(@dealer) while @dealer.hit?
    determine_winner
    process_bet
    show_outcome
  end

  def reset_table
    [@dealer, @player].each(&:clear_hand)
    @dealer.shuffle_deck
    @display.clear_table
  end

  def process_outcome
    @display.print_score_outcome(@player.total, @dealer.total)
    set_busted_totals_to_zero
    if @player.total > @dealer.total
      @round_winner = :player
      @player.money += @player.bet
    elsif @dealer.total > @player.total
      @round_winner = :dealer
      @player.money -= @player.bet
    end
    @display.print_winner(@round_winner)
  end

  def set_busted_totals_to_zero
    [@player, @dealer].each do |person|
      person.total = 0 if person.busted?
    end
  end

  def deal_initial_cards
    2.times do
      @dealer.deal(@player)
      @dealer.deal(@dealer)
    end
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
