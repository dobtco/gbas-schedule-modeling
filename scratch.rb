require 'pry'

NUM_APPLICANTS = 70
NUM_TIMESLOTS = 80
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

@timeslots = (0..NUM_TIMESLOTS - 1).map do |i|
  Timeslot.new(i)
end

@applicants = (0..NUM_APPLICANTS - 1).map do |i|
  Applicant.new(i)
end

@reviewers = (0..NUM_REVIEWERS - 1).map do |i|
  Reviewer.new(i)
end

def all_users
  (@applicants + @reviewers)
end

def timeslot_by_sequence(sequence)
  @timeslots.detect { |timeslot| timeslot.sequence = sequence }
end

def timeslots
  @timeslots
end

def applicant_booked?(applicant)
  timeslots.any? do |timeslot|
    timeslot.applicant == applicant
  end
end

def fmt_percent(num)
  sprintf('%.2f', num * 100) + '%'
end

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

@timeslots.each do |timeslot|
  timeslot.applicant = @applicants.shuffle.detect { |applicant| !applicant_booked?(applicant) && applicant.available_for_timeslot?(timeslot.sequence) }
  timeslot.reviewers = @reviewers.shuffle.select { |reviewer| reviewer.available_for_timeslot?(timeslot.sequence) }.first(2)
end

## Results

puts "% of responsive applicants booked: #{fmt_percent(@applicants.count { |app| applicant_booked?(app) } / @applicants.select(&:responded_to_availability_request?).length.to_f)}"
puts "% of slots with enough reviewers: #{fmt_percent(@timeslots.select(&:in_use?).count(&:full?) / @timeslots.select(&:is_use?).to_f)}"




