package com.mottomusic.player

import android.graphics.Color
import android.text.SpannableString
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView

/**
 * 极简歌词适配器：只负责显示，不做状态计算
 * 核心逻辑（highlightEnd计算、SpannableString构建）由Activity层处理
 */
class SimpleLyricsAdapter(
    private val onItemClick: (() -> Unit)? = null
) : RecyclerView.Adapter<SimpleLyricsAdapter.ViewHolder>() {

    private var lyrics: List<LyricLine> = emptyList()
    private var currentIndex: Int = -1
    private var currentSpannable: SpannableString? = null

    companion object {
        const val PAYLOAD_UPDATE = "update_spannable"
    }

    class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        val textView: TextView = view.findViewById(R.id.lyric_text)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.item_lockscreen_lyric, parent, false)
        val holder = ViewHolder(view)
        
        // 给每个item添加点击事件
        view.setOnClickListener {
            onItemClick?.invoke()
        }
        
        return holder
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        val lyric = lyrics[position]
        val isCurrent = position == currentIndex

        holder.textView.textSize = 28f

        if (isCurrent && currentSpannable != null) {
            // 当前行：使用Activity传入的SpannableString
            holder.textView.text = currentSpannable
            holder.textView.alpha = 1.0f
        } else if (isCurrent) {
            // 当前行：无逐字高亮
            holder.textView.text = lyric.text
            holder.textView.alpha = 1.0f
        } else {
            // 非当前行：半透明
            holder.textView.text = lyric.text
            holder.textView.alpha = 0.5f
        }
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int, payloads: MutableList<Any>) {
        if (payloads.isEmpty()) {
            onBindViewHolder(holder, position)
            return
        }

        // Payload更新：只更新当前行的SpannableString
        if (payloads.contains(PAYLOAD_UPDATE)) {
            val lyric = lyrics[position]
            if (position == currentIndex && currentSpannable != null) {
                holder.textView.text = currentSpannable
            }
        }
    }

    override fun getItemCount(): Int = lyrics.size

    /**
     * 更新歌词列表
     */
    fun updateLyrics(newLyrics: List<LyricLine>) {
        lyrics = newLyrics
        notifyDataSetChanged()
    }

    /**
     * 更新当前行（Activity层已计算好SpannableString）
     */
    fun updateCurrentLine(index: Int, spannable: SpannableString?) {
        val oldIndex = currentIndex
        currentIndex = index
        currentSpannable = spannable

        if (oldIndex != -1 && oldIndex < lyrics.size) {
            notifyItemChanged(oldIndex)
        }
        if (currentIndex != -1 && currentIndex < lyrics.size) {
            notifyItemChanged(currentIndex, PAYLOAD_UPDATE)
        }
    }
}
