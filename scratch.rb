require 'pry'
require 'active_support/all'
require 'descriptive-statistics'

args = Hash[ ARGV.join(' ').scan(/--?([^=\s]+)(?:=(\S+))?/) ]

NUM_APPLICANTS = args['applicants'] ? args['applicants'].to_i : 50
NUM_TIMESLOTS = args['timeslots'] ? args['timeslots'].to_i : 60
NUM_REVIEWERS = args['reviewers'] ? args['reviewers'].to_i : 26
REVIEWERS_PER_INTERVIEW = 2
APPLICANT_CHOOSE_COUNT = 2
REVIEWER_CHOOSE_COUNT = 6
RESPONSE_RATES_FOR_AVAILABILITY_REQUEST = {
  'Applicant' => 90,
  'Reviewer' => 97
}

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

    all_users.reject do |u|
      rand(1..100) > RESPONSE_RATES_FOR_AVAILABILITY_REQUEST[u.class.name]
    end.each(&:pick_availability!)

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

    #### Book in random order
    timeslots_in_use.each do |timeslot|
      timeslot.reviewers = @reviewers.shuffle.select do |reviewer|
        reviewer.available_for_timeslot?(timeslot.sequence)
      end.first(2)
    end

    #### Even-out the workload
    #### `10.times` was chosen via experimentation
    10.times do
      reviewers_with_lotta_work.each do |lotta_work_reviewer|
        timeslots.select { |timeslot| timeslot.reviewers.include?(lotta_work_reviewer) }.each do |timeslot|
          if (assign_to = @reviewers.detect { |r| !timeslot.reviewers.include?(r) && reviewer_workload(r) < reviewer_workload(lotta_work_reviewer) })
            timeslot.reviewers = timeslot.reviewers - [lotta_work_reviewer] + [assign_to]
          end
        end
      end
    end

    ## Results

    workload_stats = generate_workload_stats

    {
      percent_responsive_applicants_booked: booked_applicants.length / responsive_applicants.length.to_f,
      percent_slots_with_enough_reviewers: full_timeslots.length / timeslots_in_use.length.to_f,
      average_reviewer_workload: workload_stats.mean,
      reviewers_with_workflow_gt_1_sd: @reviewers.count { |r| reviewer_workload(r) > (workload_stats.mean + workload_stats.standard_deviation) } / @reviewers.length.to_f,
      reviewers_with_workflow_gt_2_sd: @reviewers.count { |r| reviewer_workload(r) > (workload_stats.mean + (workload_stats.standard_deviation * 2)) } / @reviewers.length.to_f,
      reviewers_with_workflow_gt_3_sd: @reviewers.count { |r| reviewer_workload(r) > (workload_stats.mean + (workload_stats.standard_deviation * 3)) } / @reviewers.length.to_f
    }
  end

  private

  def generate_workload_stats
    DescriptiveStatistics::Stats.new(@reviewers.map { |r| reviewer_workload(r) })
  end

  def reviewers_with_lotta_work
    workload_stats = generate_workload_stats

    @reviewers.select do |reviewer|
      reviewer_workload(reviewer) > workload_stats.mean.ceil
    end
  end

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

  def reviewer_workload(reviewer)
    timeslots.count { |timeslot| timeslot.reviewers.include?(reviewer) }
  end

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

puts "Running #{num_runs} times..."

results = Array.new(num_runs).map do
  Simulation.new.run
end

def fmt_percent(num)
  sprintf('%.2f', num * 100) + '%'
end

def fmt_number(num)
  sprintf('%.2f', num)
end

puts "% of responsive applicants booked: #{fmt_percent(results.sum { |res| res[:percent_responsive_applicants_booked] / results.length.to_f})}"
puts "% of slots with enough reviewers: #{fmt_percent(results.sum { |res| res[:percent_slots_with_enough_reviewers] / results.length.to_f})}"
puts "Average reviewer workload: #{fmt_number(results.sum { |res| res[:average_reviewer_workload] / results.length.to_f})} interviews/reviewer"
puts "% of reviewers with workflow > 1 standard deviation: #{fmt_percent(results.sum { |res| res[:reviewers_with_workflow_gt_1_sd] / results.length.to_f})}"
puts "% of reviewers with workflow > 2 standard deviation: #{fmt_percent(results.sum { |res| res[:reviewers_with_workflow_gt_2_sd] / results.length.to_f})}"
puts "% of reviewers with workflow > 3 standard deviation: #{fmt_percent(results.sum { |res| res[:reviewers_with_workflow_gt_3_sd] / results.length.to_f})}"
