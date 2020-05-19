require 'minitest/autorun'
require_relative '../lib/twenty_one.rb'
require 'pry'

class DeckTest < Minitest::Test
  def test_created_deck_size
    new_deck = Deck.new
    expected = 52
    actual = new_deck.instance_variable_get(:@cards).size
    assert_equal expected, actual
  end
end

class PlayerTest < Minitest::Test
  def setup
    display = Display.new(false)
    @player = Player.new(display)
  end

  def test_update_total1
    hand = [Card.new(:spades, 'A'), Card.new(:spades, '6'),
            Card.new(:spades, '10'), Card.new(:spades, 'A')]
    @player.instance_variable_set :@hand, hand
    total = @player.update_total

    expected = 18
    actual = total
    assert_equal expected, actual
  end

  def test_update_total2
    hand = [Card.new(:spades, 'A'), Card.new(:spades, '2'),
            Card.new(:spades, '6'), Card.new(:spades, 'A')]
    @player.instance_variable_set :@hand, hand
    total = @player.update_total

    expected = 20
    actual = total
    assert_equal expected, actual
  end
end

class DealerTest < Minitest::Test
  def setup
    display = Display.new(false)
    @player = Player.new(display)
    @dealer = Dealer.new(display)
  end

  def test_dealer_deals_two_cards_to_player
    @dealer.deal(2, @player)
    expected = 2
    actual = @player.instance_variable_get(:@hand).size
    assert_equal expected, actual
  end

  def test_dealer_deals_two_cards_to_self
    @dealer.deal(2)
    expected = 2
    actual = @dealer.instance_variable_get(:@hand).size
    assert_equal expected, actual
  end
end

class Display_Test < Minitest::Test
  def setup
    @display = Display.new(false)
  end

  def test_creates_blank_card_copy
    expected = [
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
    actual = @display.blank_card_copy
    assert_equal expected, actual
  end
  
  def test_new_card_doesnt_mutate_other_cards
    card1 = @display.blank_card_copy
    card2 = @display.blank_card_copy
    card1[1,1] = '1'
    refute_equal card1, card2
  end
end
