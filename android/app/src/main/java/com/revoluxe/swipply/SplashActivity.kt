package com.revoluxe.swipply

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.view.animation.AccelerateDecelerateInterpolator
import android.widget.TextView

class SplashActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.splash_screen)

        val logo = findViewById<TextView>(R.id.swipplyText)

        logo.animate()
            .translationX(0f)
            .alpha(1f)
            .setDuration(1000)
            .setInterpolator(AccelerateDecelerateInterpolator())
            .withEndAction {
                logo.animate()
                    .scaleX(1.2f)
                    .scaleY(1.2f)
                    .alpha(0.6f)
                    .setDuration(600)
                    .withEndAction {
                       startActivity(Intent(this, MainActivity::class.java))


                        finish()
                    }
                    .start()
            }
            .start()
    }
}
