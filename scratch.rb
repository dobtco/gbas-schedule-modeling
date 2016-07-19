require 'pry'
require 'active_support/all'
require 'descriptive-statistics'
require 'yaml'

## Constants

NUM_APPLICANTS = 60
NUM_REVIEWERS = 26
NUM_TIMESLOTS = 66
REVIEWERS_PER_INTERVIEW = 2
APPLICANT_CHOOSE_COUNT = 2
REVIEWER_CHOOSE_COUNT = 6
CONCURRENCY = 2
RESPONSE_RATES_FOR_AVAILABILITY_REQUEST = {
  'Applicant' => 90,
  'Reviewer' => 97
}
NUM_EVENTS = NUM_TIMESLOTS * CONCURRENCY

## Simple validation

if NUM_APPLICANTS > NUM_EVENTS
  fail 'Not enough events for all applicants to be interviewed.'
end

if (NUM_REVIEWERS * REVIEWER_CHOOSE_COUNT) < (REVIEWERS_PER_INTERVIEW * NUM_APPLICANTS)
  fail 'Not enough reviewers to staff all the interviews.'
end

class Timeslot
  attr_accessor :reviewers, :applicant, :sequence

  def initialize(sequence)
    self.sequence = sequence
    self.reviewers = []
  end

  def full?
    if applicant && (reviewers.length == REVIEWERS_PER_INTERVIEW)
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

  def pick_availability!
    seed = [
      [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0],
      [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      [0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0],
      [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      [0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      [0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      [0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0],
      [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,1,1,1,0,0,0,0,0,0],
      [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      [0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,1,0,0,0,0,0,0,0],
      [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      [1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,1,1,1,1,1,1,1,1,1,1,1,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
      [1,1,1,1,1,1,1,1,1,1,1,0,0,1,1,1,1,1,0,1,1,1,1,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,1,1,1,1,1,1],
      [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0],
      [0,0,1,1,0,1,1,0,0,1,1,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,1,1,0,0,0],
      [1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,1,0,0,0,1,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,1,0],
      [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,1,0,0,1,1,0,0,0,0,0,0,0,0,0,1,1],
      [0,0,0,0,1,1,0,0,0,0,0,0,0,0,1,0,1,1,0,0,0,0,0,0,1,0,1,0,1,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1]
    ]

    # If a reviewer picks *all* timeslots
    # if self.class.name == 'Reviewer' && sequence.in?([0])
    #   NUM_TIMESLOTS.times do |i|
    #     availability << i
    #   end
    # else

    if self.class.name == 'Reviewer'
      (0..(NUM_TIMESLOTS - 1)).each do |x|
        if seed[sequence][x] == 1
          availability << (x * 2)
          availability << (x * 2) + 1
        end
      end
    else
      randomized_choose_count.times do
        timeslot_sequences_at_same_time(new_random_choice).each do |x|
          availability << x
        end
      end
    end
  end

  def timeslot_sequences_at_same_time(sequence)
    (0..(NUM_EVENTS - 1)).select do |x|
      (x / CONCURRENCY) == (sequence / CONCURRENCY)
    end
  end

  # Users won't always pick the # of slots that they're asked to pick
  def randomized_choose_count
    [
      choose_count - 2,
      choose_count - 1,
      choose_count,
      choose_count,
      choose_count,
      choose_count,
      choose_count,
      choose_count,
      choose_count,
      choose_count,
      choose_count,
      choose_count,
      choose_count,
      choose_count,
      choose_count + 1,
      choose_count + 1,
      choose_count + 2,
      choose_count + 2,
      choose_count + 3
    ].sample
  end

  def new_random_choice
    choice = rand(0..(NUM_EVENTS - 1))

    if availability.include?(choice)
      new_random_choice
    else
      choice
    end
  end

  def responded_to_availability_request?
    availability.length > 0
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
end

class Simulation
  attr_reader :timeslots, :applicants, :reviewers

  def initialize
    @timeslots = (0..NUM_EVENTS - 1).map do |i|
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
    starting_events = serialize_events

    starting_unbooked_applicants = unbooked_responsive_applicants
    book_applicants_in_random_order
    recursively_book_unbooked_applicants(starting_unbooked_applicants)
    book_reviewers_in_random_order

    starting_events.all? do |event|
      if !serialize_events.include?(event)
        fail 'This run was not safe!'
      end
    end
  end

  def most_users_indicate_availability
    unresponsive_users.reject do |u|
      rand(1..100) > RESPONSE_RATES_FOR_AVAILABILITY_REQUEST[u.class.name]
    end.each(&:pick_availability!)
  end

  def results
    workload_stats = generate_workload_stats

    {
      num_applicants_booked: booked_applicants.length,
      percent_responsive_applicants_booked: booked_applicants.length / responsive_applicants.length.to_f,
      percent_slots_with_enough_reviewers: full_timeslots.length / timeslots_in_use.length.to_f,
      average_reviewer_workload: workload_stats.mean,
      standard_deviation: workload_stats.standard_deviation,
      max_interviews: reviewers.map do |r|
        reviewer_workload(r)
      end.max
    }
  end

  def validate_results
    timeslots.each do |ts|
      if ts.reviewers[0].present? && ts.reviewers[0] == ts.reviewers[1]
        fail "Can't book the same reviewer twice in the same slot!"
      end
    end

    reviewers.each do |reviewer|
      booked_sequences = timeslots.select { |timeslot| timeslot.reviewers.include?(reviewer) }.map(&:sequence).map { |x| x / CONCURRENCY }

      if booked_sequences.length != booked_sequences.uniq.length
        fail "Can't book the same reviewer twice at the same time."
      end
    end
  end

  private

  # @return Array of [timeslot, user] pairs
  def serialize_events
    [].tap do |arr|
      timeslots.each do |timeslot|
        if timeslot.applicant
          arr << [timeslot, timeslot.applicant]
        end

        timeslot.reviewers.each do |reviewer|
          arr << [timeslot, reviewer]
        end
      end
    end
  end

  def book_reviewers_in_random_order
    booked = []

    timeslots_in_need_of_reviewers.each do |timeslot|
      reviewers_needed = REVIEWERS_PER_INTERVIEW - timeslot.reviewers.length

      add_reviewers = reviewers.shuffle.select do |reviewer|
        user_available_for_timeslot?(reviewer, timeslot)
      end.first(reviewers_needed)

      add_reviewers.each do |reviewer|
        booked << [timeslot, reviewer]
        timeslot.reviewers << reviewer
      end
    end

    even_out_reviewer_workload(booked)
  end

  def user_available_for_timeslot?(user, timeslot)
    if user.is_a?(Reviewer)
      user.availability.include?(timeslot.sequence) &&
      timeslots_at_time(timeslot).none? { |timeslot| timeslot.reviewers.include?(user) }
    else
      user.availability.include?(timeslot.sequence)
    end
  end

  def timeslots_at_time(timeslot)
    timeslots.select do |ts|
      (ts.sequence / CONCURRENCY) == (timeslot.sequence / CONCURRENCY)
    end
  end

  def timeslots_in_need_of_reviewers
    timeslots_in_use.select do |timeslot|
      timeslot.reviewers.length < REVIEWERS_PER_INTERVIEW
    end
  end

  # `10.times` was chosen via experimentation
  def even_out_reviewer_workload(new_events)
    10.times do
      reviewers_with_lotta_work.each do |lotta_work_reviewer|
        timeslots.select { |timeslot| timeslot.reviewers.include?(lotta_work_reviewer) }.each do |timeslot|
          if new_events.include?([timeslot, lotta_work_reviewer])
            if (assign_to = reviewers.detect { |r| user_available_for_timeslot?(r, timeslot) && reviewer_workload(r) < reviewer_workload(lotta_work_reviewer) })
              new_events = new_events - [[timeslot, lotta_work_reviewer]] + [[timeslot, assign_to]]
              timeslot.reviewers = timeslot.reviewers - [lotta_work_reviewer] + [assign_to]
            end
          end
        end
      end
    end
  end

  def book_applicants_in_random_order
    available_timeslots.each do |timeslot|
      timeslot.applicant = applicants.shuffle.detect do |applicant|
        !applicant_booked?(applicant) && user_available_for_timeslot?(applicant, timeslot)
      end
    end
  end

  def recursively_book_unbooked_applicants(only_change_applicants)
    unbooked_responsive_applicants.each { |applicant| book_applicant!(applicant, 0, only_change_applicants) }
  end

  def generate_workload_stats
    DescriptiveStatistics::Stats.new(reviewers.map { |r| reviewer_workload(r) })
  end

  def reviewers_with_lotta_work
    workload_stats = generate_workload_stats

    reviewers.select do |reviewer|
      reviewer_workload(reviewer) > workload_stats.mean.ceil
    end
  end

  def book_applicant!(applicant, depth, only_change_applicants, max_recursion = 10)
    current_sequence = timeslots.detect { |ts| ts.applicant == applicant }.try(:sequence)

    available_timeslots = timeslots.select do |timeslot|
      user_available_for_timeslot?(applicant, timeslot)
    end

    empty_slot = available_timeslots.detect(&:empty?)

    if empty_slot
      empty_slot.applicant = applicant
    elsif depth < max_recursion
      new_sequence = applicant.availability.sample
      timeslot = timeslot_by_sequence(new_sequence)
      previous_applicant = timeslot.applicant

      if previous_applicant.in?(only_change_applicants)
        timeslot.applicant = applicant
        book_applicant!(previous_applicant, depth + 1, only_change_applicants)
      end
    end
  end

  def reviewer_workload(reviewer)
    timeslots.count { |timeslot| timeslot.reviewers.include?(reviewer) }
  end

  def responsive_applicants
    applicants.select(&:responded_to_availability_request?)
  end

  def booked_applicants
    applicants.select { |app| applicant_booked?(app) }
  end

  def unbooked_responsive_applicants
    responsive_applicants.reject { |app| applicant_booked?(app) }
  end

  def full_timeslots
    timeslots_in_use.select(&:full?)
  end

  def timeslots_in_use
    timeslots.select(&:in_use?)
  end

  def available_timeslots
    timeslots.reject(&:in_use?)
  end

  def all_users
    (applicants + reviewers)
  end

  def unresponsive_users
    all_users.select { |u| u.availability.blank? }
  end

  def timeslot_by_sequence(sequence)
    timeslots.detect { |timeslot| timeslot.sequence == sequence }
  end

  def applicant_booked?(applicant)
    timeslots.any? do |timeslot|
      timeslot.applicant == applicant
    end
  end
end

class ResultPrinter < Struct.new(:results)
  def fmt_percent(num)
    sprintf('%.2f', num * 100) + '%'
  end

  def fmt_number(num)
    sprintf('%.2f', num)
  end

  def print
    puts "# of applicants booked: #{fmt_number(results.sum { |res| res[:num_applicants_booked] / results.length.to_f})}"
    puts "% of responsive applicants booked: #{fmt_percent(results.sum { |res| res[:percent_responsive_applicants_booked] / results.length.to_f})}"
    puts "% of slots with enough reviewers: #{fmt_percent(results.sum { |res| res[:percent_slots_with_enough_reviewers] / results.length.to_f})}"
    puts "Average reviewer workload: #{fmt_number(results.sum { |res| res[:average_reviewer_workload] / results.length.to_f})} interviews/reviewer"
    puts "Reviewer workload: standard deviation: #{fmt_number(results.sum { |res| res[:standard_deviation] / results.length.to_f})}"
    puts "Max # of interviews per reviewer: #{fmt_number(results.sum { |res| res[:max_interviews] / results.length.to_f})}"
  end
end

class TimeslotPrinter < Struct.new(:simulation)
  def print
    i = 0
    simulation.timeslots.each_slice(CONCURRENCY) do |slice|
      puts "## Time #{i += 1}"

      slice.each do |ts|
        puts "|-----------------"

        if ts.in_use?
          puts "| Applicant: #{ts.applicant.try(:sequence)}"
          puts "| Reviewer 1: #{ts.reviewers[0].try(:sequence)}"
          puts "| Reviewer 2: #{ts.reviewers[1].try(:sequence)}"
        else
          puts "| Not in use"
        end

        puts "|-----------------\n\n"
      end

      puts "\n"
    end
  end
end

num_runs = 50

puts "Running #{num_runs} times..."

results = Array.new(num_runs).map do
  sim = Simulation.new

  2.times do
    sim.most_users_indicate_availability
    sim.run
  end

  sim.validate_results

  sim.results
end

ResultPrinter.new(results).print
