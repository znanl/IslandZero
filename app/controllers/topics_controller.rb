class TopicsController < ApplicationController

  if IslandZero.open_to_public
    before_action :authenticate_user!,  except: [:index, :show]
  else
    before_action :authenticate_user!
  end

  before_action :authenticate_admin!, only: [:edit, :update, :new, :create]
  before_action :set_topic, only: [:show, :edit, :update, :destroy]

  respond_to :html

  def index
    params[:parent_id] = 0 unless params[:parent_id].present?
    @topics = Topic.where(params.permit(:parent_id)).order(:rank)
    respond_with(@topics)
  end

  def show
    # Setup message
    @chattable = @topic
    if user_signed_in?
      @new_message= Message.new(chattable: @topic)
    end

    # Reveal Objects
    @posts  = @topic.all_posts.order("id DESC").paginate(:page => params[:page])
    @sub_topics = @topic.sub_topics.order(:rank)

    # Form for tricks
    if user_signed_in?
      @new_post   = Post.new(topic: @topic)
    end

    # Update visited_at
    if user_signed_in?
      @topic.mark_visited current_user
    end

    # Render
    respond_with(@topic)
  end

  def new
    @topic = Topic.new(params.permit(:parent_id))
    respond_with(@topic)
  end

  def edit
  end

  def create
    @topic = Topic.new(topic_params)
    @topic.save

    # Update parent all_sub_topic_ids
    @topic.update_all_parents_with_sub_topic_ids

    respond_with(@topic)
  end

  def update
    old_parent = @topic.parent_topic

    @topic.update(topic_params)

    # Update parent all_sub_topic_ids
    @topic.update_all_parents_with_sub_topic_ids

    # Update old parent if necessary
    if old_parent.present? and old_parent.id != @topic.parent_id
      old_parent.update_all_sub_topic_ids
      old_parent.update_all_parents_with_sub_topic_ids
    end

    respond_with(@topic)
  end

  def destroy
    @topic.destroy

    # Update parent all_sub_topic_ids
    @topic.update_all_parents_with_sub_topic_ids

    respond_with(@topic)
  end

  private
    def set_topic
      @topic = Topic.find(params[:id])
    end

    def topic_params
      params.require(:topic)
      .permit(:title, :introduction, :parent_id, :rank, :icon)
      .clean_strict(:title)
      .clean_basic(:content)
    end
end
