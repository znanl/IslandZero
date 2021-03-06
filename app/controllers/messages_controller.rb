class MessagesController < ApplicationController
  before_action :authenticate_user!

  def create
    post_params = params.require(:message)
    .permit(:chattable_id, :chattable_type, :content)
    .clean_strict(:content)

    # Check and return error
    if post_params[:content].blank?
      if request.xhr?
        render plain: t(:content_missing), status: 400
      else
        flash.alert = t(:content_missing)
        redirect_back
      end
      return
    end

    # Check Duplicated Message
    msg_hash = Digest::SHA1.hexdigest(post_params[:content])
    lock_key = "lock.dm.#{current_user.id}"
    if $redis.get(lock_key) == msg_hash
      if request.xhr?
        render plain: t(:pls_no_duplicated_message), status: 400
      else
        flash.alert = t(:pls_no_duplicated_message)
        redirect_back
      end
      return
    else
      $redis.setex(lock_key, 3, msg_hash)
    end

    # Create model
    @message = current_user.messages.create(post_params)

    # Push to channel
    RealtimeChatController.publish "/chat/#{@message.chattable_type}/#{@message.chattable_id}", {
      user_id:        @message.user.id,
        user_nickname:  @message.user.nickname,
        content:        @message.content,
        created_at:     @message.created_at,
        _html:          render_to_string(partial: 'shared/chatitem', locals: { msg: @message })
    }

    # Render
    if request.xhr?
      render nothing: true
    else
      redirect_back
    end
  end

end
