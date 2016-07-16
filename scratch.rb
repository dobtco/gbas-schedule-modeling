require 'pry'
require 'active_support/all'

NUM_APPLICANTS = 70
NUM_TIMESLOTS = 100
NUM_REVIEWERS = 30
REVIEWERS_PER_INTERVIEW = 2
APPLICANT_CHOOSE_COUNT = 2
REVIEWER_CHOOSE_COUNT = 5
RESPONSE_RATE_FOR_AVAILABILITY_REQUEST = 90

# Users won't always pick the # of slots that they're asked to pick
def randomized_choose_count(ask)
  [
    ask - 2,
    ask - 1,
    ask,
    ask,
    ask,
    ask,
    ask,
    ask,
    ask,
    ask,
    ask,
    ask,
    ask,
    ask,
    ask + 1,
    ask + 1,
    ask + 2,
    ask + 2,
    ask + 3
  ].sample
end

class Timeslot
  attr_accessor :reviewers, :applicant, :sequence

  def initialize(sequence)
    self.sequence = sequence
    self.reviewers = []
  end

  def full?
    if applicant && (reviewers.length == 2)
      true
    else
      false
    end
  end

  def in_use?
    !!applicant
  end

  def empty?
    !in_use?
  end

  def to_s
    "#<Timeslot sequence=#{sequence} full=#{full?} applicant=#{applicant} primary_reviewer=#{reviewers[0]} secondary_reviewer=#{reviewers[1]}>"
  end
end

class User
  attr_accessor :availability, :sequence

  def initialize(sequence)
    self.sequence = sequence
    self.availability = []
  end

  def to_s
    "#{self.class.name} ##{sequence}"
  end

  def available_for_timeslot?(sequence)
    availability.include?(sequence)
  end

  def pick_availability!
    randomized_choose_count(choose_count).times do
      availability << new_random_choice
    end
  end

  def new_random_choice
    choice = rand(0..(NUM_TIMESLOTS - 1))

    if availability.include?(choice)
      new_random_choice
    else
      choice
    end
  end
end

class Reviewer < User
  def choose_count
    REVIEWER_CHOOSE_COUNT
  end
end

class Applicant < User
  def choose_count
    APPLICANT_CHOOSE_COUNT
  end

  def responded_to_availability_request?
    availability.length > 0
  end
end

class Simulation
  def initialize
    @timeslots = (0..NUM_TIMESLOTS - 1).map do |i|
      Timeslot.new(i)
    end

    @applicants = (0..NUM_APPLICANTS - 1).map do |i|
      Applicant.new(i)
    end

    @reviewers = (0..NUM_REVIEWERS - 1).map do |i|
      Reviewer.new(i)
    end
  end

  def run
    ## Guards

    if NUM_APPLICANTS > NUM_TIMESLOTS
      fail 'Not enough timeslots for all applicants to be interviewed.'
    end

    if (NUM_REVIEWERS * REVIEWER_CHOOSE_COUNT) < (REVIEWERS_PER_INTERVIEW * NUM_APPLICANTS)
      fail 'Not enough reviewers to staff all the interviews.'
    end

    ## Pick Availability

    all_users.
      reject { |_| rand(1..100) > RESPONSE_RATE_FOR_AVAILABILITY_REQUEST }.
      each(&:pick_availability!)

    ## This is the "algorithm", lol?

    ### First pass

    @timeslots.each do |timeslot|
      timeslot.applicant = @applicants.shuffle.detect do |applicant|
        !applicant_booked?(applicant) && applicant.available_for_timeslot?(timeslot.sequence)
      end
    end

    ### Book as many applicants as possible

    unbooked_responsive_applicants.each { |applicant| book_applicant!(applicant, 0) }

    ### Now, book the reviewers

    ## Results
    {
      percent_responsive_applicants_booked: booked_applicants.length / responsive_applicants.length.to_f,
      percent_slots_with_enough_reviewers: full_timeslots.length / timeslots_in_use.length.to_f
    }
  end

  private

  def book_applicant!(applicant, depth = 0, max_recursion = 10)
    current_sequence = timeslots.detect { |ts| ts.applicant == applicant }.try(:sequence)

    available_timeslots = timeslots.select { |timeslot| applicant.available_for_timeslot?(timeslot.sequence) }
    empty_slot = available_timeslots.detect(&:empty?)

    if empty_slot
      empty_slot.applicant = applicant
    elsif depth < max_recursion
      new_sequence = applicant.availability.sample
      timeslot = timeslot_by_sequence(new_sequence)
      previous_applicant = timeslot.applicant
      timeslot.applicant = applicant
      book_applicant!(previous_applicant, depth + 1)
    end
  end

  # def rebook_applicant!(applicant, depth = 0)
  #   current_sequence = timeslots.detect { |ts| ts.applicant == applicant }.try(:sequence)

  #   available_timeslot = (applicant.availability - [current_sequence]).detect do |sequence|
  #     !timeslot_by_sequence(sequence).in_use?
  #   end

  #   if available_timeslot
  #     available_timeslot.applicant = applicant
  #     true
  #   else
  #     false
  #   end
  # end

  def responsive_applicants
    @applicants.select(&:responded_to_availability_request?)
  end

  def booked_applicants
    @applicants.select { |app| applicant_booked?(app) }
  end

  def unbooked_responsive_applicants
    responsive_applicants.reject { |app| applicant_booked?(app) }
  end

  def full_timeslots
    timeslots_in_use.select(&:full?)
  end

  def timeslots_in_use
    @timeslots.select(&:in_use?)
  end

  def all_users
    (@applicants + @reviewers)
  end

  def timeslot_by_sequence(sequence)
    @timeslots.detect { |timeslot| timeslot.sequence == sequence }
  end

  def timeslots
    @timeslots
  end

  def applicant_booked?(applicant)
    timeslots.any? do |timeslot|
      timeslot.applicant == applicant
    end
  end
end

num_runs = 50

results = Array.new(num_runs).map do
  Simulation.new.run
end

def fmt_percent(num)
  sprintf('%.2f', num * 100) + '%'
end

puts "Out of #{num_runs} runs..."

puts "% of responsive applicants booked: #{fmt_percent(results.sum { |res| res[:percent_responsive_applicants_booked] / results.length.to_f})}"
puts "% of slots with enough reviewers: #{fmt_percent(results.sum { |res| res[:percent_slots_with_enough_reviewers] / results.length.to_f})}"
