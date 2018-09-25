#!/usr/bin/perl

use strict;
use warnings;
use IO::Handle;


# Match conditions
use constant MATCH_FACE_VALUE => 0;
use constant MATCH_SUIT => 1;
use constant MATCH_VALUE_OR_SUIT => 2;

use constant CARDS_IN_SUIT => 13;
use constant CARDS_IN_DECK => 52;

# Treat cards as 0-51 then use modulo to map to suit and face value.
my @suits = qw/Clubs Diamonds Hearts Spades/;
my @facevalues = qw/Ace 2 3 4 5 6 7 8 9 10 Jack Queen King/;

main();

sub main {
    my ($pack_count, $match_method) = get_start_values();
    my @player1_cards = ();
    my @player2_cards = ();
    my $pile = create_card_pile($pack_count);
    printf("Pile size %d\n", scalar(@$pile));

    my $last_card = $pile->[0];
    my $idx = 1;
    my @discards = ($last_card);

    # Run the simulation
    while ($idx <= $#{$pile}) {
        my $card = $pile->[$idx++];
        printf("Last card: %20s   Current card: %20s\t",
               cardname($last_card), cardname($card));

        push(@discards, $card);
        if (match_cards($match_method, $last_card, $card)) {
            my $winner = pick_winner();
            print("Player$winner wins\n");
            if ($winner == 1) {
                push(@player1_cards, @discards);
            } else {
                push(@player2_cards, @discards);
            }
            @discards = ();
            $last_card = undef;

            # The 'current' card has been given to a winner so get the next one
            last if ($idx > $#{$pile});
            $card = $pile->[$idx++];
            push(@discards, $card);
        } else {
            print("\n");
        }
        $last_card = $card;
    }

    my $player1_count = scalar(@player1_cards);
    my $player2_count = scalar(@player2_cards);
    printf("Finished playing, have %d unclaimed cards\n", scalar(@discards));
    printf("Player1 has %d cards, Player2 has %d cards\n", $player1_count, $player2_count);
    if ($player1_count > $player2_count) {
        print "Player1 is the winner!\n";
    } elsif ($player1_count < $player2_count) {
        print "Player2 is the winner!\n";
    } else {
        print "Its a draw\n";
    }
}

# Map a card to its suit (0-3)
sub suit_idx {
    my $card = shift;
    return int ($card / CARDS_IN_SUIT);
}


# Map a card to its face value (0-12)
sub facevalue_idx {
    my $card = shift;
    return $card % CARDS_IN_SUIT;
}


sub cardname {
    my $card = shift;

    die "Invalid card: $card\n" if $card >= CARDS_IN_DECK;
    my $suit = $suits[suit_idx($card)];
    my $facevalue = $facevalues[facevalue_idx($card)];

    return "$facevalue of $suit";
}


sub match_cards {
    my ($match_condition, $card1, $card2) = @_;

    if ($match_condition == MATCH_FACE_VALUE) {
        return facevalue_idx($card1) == facevalue_idx($card2);
    } elsif ($match_condition == MATCH_SUIT) {
        return suit_idx($card1) == suit_idx($card2);
    } elsif ($match_condition == MATCH_VALUE_OR_SUIT) {
        return (suit_idx($card1) == suit_idx($card2)) ||
          (facevalue_idx($card1) == facevalue_idx($card2));
    } else {
        die "Invalid match condition: $match_condition\n";
    }
}


# Pick the player who won the round using the lowest random number.
sub pick_winner {
    my $player1 = rand();
    my $player2 = rand();
    die "RNG is not very random\n" if ($player1 == $player2);
    return ($player1 < $player2) ? 1 : 2;
}


# Create an array of cards that are 'shuffled' by using a random
# number to determine the location of the next card in the array.
# If the position is already filled just do a linear scan for the
# next available slot.
sub create_card_pile {
    my $pack_count = shift;

    my $total_cards = $pack_count * CARDS_IN_DECK;

    # Presize the array to avoid reallocing as items are added
    my @initial_pile = ();
    $#initial_pile = $total_cards - 1;
    my $next_card = 0;

    for (my $i = 0; $i < $total_cards; $i++) {
        my $card = ($next_card++ % CARDS_IN_DECK);
        my $pos = rand($total_cards);
        while (defined $initial_pile[$pos]) {
            $pos = ($pos + 1) % $total_cards;
        }
        $initial_pile[$pos] = $card;
    }
    print("Created shuffled deck of $total_cards cards\n");

    # Return a reference in case the array is very large
    return \@initial_pile;
}


sub read_number {
    chomp (my $input = <STDIN>);
    die "Input must be a positive number\n" if $input !~ /^\d+$/;
    return int $input;
}


sub get_start_values {
    STDOUT->autoflush(1);
    STDERR->autoflush(1);
    print('How many packs to use: ');

    my $pack_count = read_number() || die "Need at least 1 pack\n";
    print q|0: Face value
1: Suit
2: Both
Enter card matching method (0-2): |;

    my $match_method = read_number();
    die "Invalid matching method\n" if ($match_method > 2);
    print "Using ${pack_count} packs with method: ${match_method}\n";
    return ($pack_count, $match_method);
}


__END__

Notes:

I interpreted 'Both' to mean Face value OR suit, not Face value AND suit (ie exactly the
same card).

Treating the cards as numbers makes for faster comparisions.

The maximum number of card packs to use is not specified so some reasonable
steps are taken if N is very large:

1. The array for the shuffled deck is created using random inserts rather than
  creating an array and then chopping it up and moving slices around. With a large
  number of cards there would be a lot of heap pressure and memory copying.

2. The array is passed back by reference and when cards are removed from the pile
  the next card is retrieved by index rather than using 'shift'. This makes the logic
  slightly more involved when handling a match and 2 new cards need to be picked.

Picking the player that wins the match could fail if 'rand()' returns the same number
twice which could happen but is more likely to indicate a broken random number generator.
Of course it could be wrapped in a small loop of 2 or 3 to check for this or alternatively
the test could be <= instead of < but this would bias it slightly in favour of player1.

Shuffling the deck using random inserts is problematic as the array fills up because the
random slot that is next picked is more likely to be filled and this then involves more
scans of the array. With a very large deck count and >50% of the array filled this would
make most of the random inserts into array scans which is none optimal.

Rather than holding an array of cards each player has won, it could just hold the count
of the cards.

Deciding how to shuffle a deck in a reasonable way is actually the hardest part and would
benefit from more time to implement a better/faster algorithm.
