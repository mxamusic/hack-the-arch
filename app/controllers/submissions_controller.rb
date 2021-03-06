class SubmissionsController < ApplicationController
  before_action :logged_in_user, only: [:index, :create, :new]
  before_action :belong_to_team, only: [:create, :new]
  before_action :competition_active, only: [:create, :new]
  before_action :admin_user, only: [:index]

  def index
    @submissions = Submission.order(id: :desc)
  end

  def new
  end

  def create
    correct = false
    points = 0
    user_solution = params[:submission][:value]
    @problem = Problem.find(params[:submission][:id])
    correct_solution = @problem.solution

    # If the solution is not case sensitive
    if (!@problem.solution_case_sensitive?)
      user_solution.upcase!
      correct_solution.upcase!
    end

    # If limit has been reached
    if (max = max_submissions_per_team) > 0 &&
        current_team.submissions.where(problem: @problem).count >= max
      flash[:warning] = "Your team has alread used the maximum number of guesses for this problem!"
      redirect_to @problem
      return

    # If the solution is correct
    elsif user_solution == correct_solution
      correct = true

      # And it has not already been solved
      if @problem.solved_by?(current_user.team_id)
        flash[:warning] = "Your team has already solved this!"
        redirect_to @problem
      else
        flash[:success] = @problem.correct_message
        points = @problem.points
        redirect_to @problem
      end

    # Or the answer has already been guessed
    elsif @problem.solved_by?(current_user.team_id) 
      flash[:warning] = "Your team has already guessed that!"
      redirect_to @problem
    else
      flash[:danger] = @problem.false_message
      redirect_to @problem
    end

    Submission.create(team_id:  current_user.team_id,
                      user_id: current_user.id,
                      problem_id: @problem.id,
                      submission: user_solution,
                      correct: correct,
                      points: points)

    if correct and scoring_notifications?
      Message.create(user_id: User.where(admin: true).first.id,
                     priority: :success,
                     url: scoreboard_path,
                     message: "#{current_user.username} just scored " +
                              "#{points} points for " +
                              "#{current_user.team.name}!")
    end

  end

  private
    def belong_to_team
      unless current_user.team_id
        flash[:danger] = "You cannot solve problems unless you belong to a team!"
        redirect_to @problem
      end
    end

end
