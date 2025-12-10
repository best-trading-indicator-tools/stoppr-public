# Stoppr - Sugar Cravings Management App

A comprehensive Flutter application designed to help users manage and overcome sugar cravings through behavioral science, community support, and personalized tracking.

## License

MIT License

Copyright (c) 2025 Stoppr

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Table of Contents

- [⚠️ IMPORTANT LEGAL NOTICE](#-important-legal-notice)
- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Setup Instructions](#setup-instructions)
- [Configuration Guide](#configuration-guide)
- [Config Files Generation](#config-files-generation)
- [Development Guide](#development-guide)
- [Building & Running](#building--running)
- [Contributing](#contributing)

## ⚠️ IMPORTANT LEGAL NOTICE

**This app was banned from the Apple App Store.** This repository is provided **for educational and inspirational purposes only**.

**DO NOT use this codebase as-is** if you plan to submit to the App Store. Use this repository as a learning resource and inspiration, not as a template to copy.

## Overview

Stoppr is a mobile application built with Flutter that helps users break free from sugar addiction through:

- **Personalized Onboarding**: Comprehensive questionnaire and analysis to understand user's relationship with sugar
- **Streak Tracking**: Real-time tracking of sugar-free days with motivational widgets
- **Community Support**: Social features including posts, comments, and accountability partners
- **Educational Content**: Video lessons and articles about sugar addiction and health
- **Crisis Intervention**: Panic button feature for moments of temptation
- **Nutrition Tracking**: Food scanning, calorie tracking, and meal rating
- **Meditation & Mindfulness**: Breathing exercises and meditation sessions
- **Recipe Database**: Sugar-free recipes and meal alternatives

### App Flow: Onboarding-First, Then Paywalls

**Important**: Stoppr follows an **onboarding-first** approach. This means:

1. **Users complete the full onboarding experience FIRST** - They go through a comprehensive 13-question questionnaire, see personalized benefits, set goals, and understand the value of the app
2. **Paywalls appear AFTER onboarding** - Only after users have invested time and seen the value do they encounter subscription options
3. **Multiple paywall opportunities** - Paywalls can appear at strategic points:
   - **Pre-Paywall Screen** (`pre_paywall.dart`): After completing the questionnaire and seeing their personalized analysis, users see a "Become a STOPPR" button that triggers the main paywall
   - **Soft Paywall** (`give_us_ratings_screen.dart`): A lighter paywall that may appear during onboarding if users try to skip certain steps
   - **Feature Paywalls**: Throughout the app, certain premium features trigger paywalls when free users try to access them (e.g., food scanning, advanced panic button features, unlimited learn videos)

**Why this approach?** Users are more likely to subscribe after they've experienced the app's value and personalized content, rather than being asked to pay immediately upon opening the app.

## Features


### Core Modules

#### 1. Onboarding Flow

**Flow Overview**: Users go through a comprehensive onboarding experience BEFORE seeing any paywalls. This builds trust and demonstrates value. The onboarding is designed to be engaging, personalized, and educational - helping users understand their relationship with sugar before asking them to commit financially.

**Complete Step-by-Step Flow** (Screen by Screen):

1. **Welcome & Quiz Introduction** (`onboarding_screen2.dart`)
   - **What happens**: Users see an introduction to Stoppr with a call-to-action to start a quiz
   - **Purpose**: Creates initial engagement and sets expectations
   - **User action**: Taps "Start Quiz" button

2. **FOMO Stats Screen** (`onboarding_fomo_stats_screen.dart`)
   - **What happens**: Displays shocking statistics about sugar consumption (e.g., "The average person consumes X pounds of sugar per year")
   - **Purpose**: Creates awareness and urgency (Fear Of Missing Out on better health)
   - **User action**: Taps continue

3. **Authentication Screen** (`onboarding_screen3.dart`)
   - **What happens**: Users can sign in with:
     - Apple Sign In (iOS)
     - Google Sign In
     - Email/Password
     - Skip (continue as anonymous/guest)
   - **Purpose**: Creates user account for data persistence and cross-device sync
   - **User action**: Chooses authentication method or skips

4. **13-Question Questionnaire** (`questionnaire_screen.dart`)
   - **What happens**: Users answer 13 comprehensive questions covering:
     - Question 1-5: Current sugar consumption habits (how much, how often, when)
     - Question 6-8: Symptoms and health concerns (energy levels, mood, physical symptoms)
     - Question 9-11: Goals and motivations (why they want to quit sugar)
     - Question 12-13: Challenges and pain points (what makes it hard)
   - **Purpose**: Collects data to personalize the entire experience
   - **User action**: Answers each question (multiple choice, sliders, or text input)
   - **Data stored**: Answers saved to Firestore for analysis

5. **Profile Setup** (`profile_info_screen.dart`)
   - **What happens**: Collects basic demographic information:
     - Age
     - Gender
     - Name (optional)
   - **Purpose**: Personalizes messaging and recommendations
   - **User action**: Fills in profile information

6. **Symptoms Screen** (`symptoms_screen.dart`)
   - **What happens**: Users select from a list of symptoms they experience related to sugar consumption:
     - Low energy
     - Mood swings
     - Brain fog
     - Weight gain
     - Sleep issues
     - etc.
   - **Purpose**: Identifies specific health concerns to address
   - **User action**: Selects multiple symptoms

7. **Sugar Pain Points** (`onboarding_sugar_painpoints_page_view.dart`)
   - **What happens**: Users swipe through pages and select their biggest challenges:
     - Cravings at specific times
     - Emotional eating
     - Social pressure
     - Hidden sugars in foods
     - etc.
   - **Purpose**: Identifies specific pain points to address in the app experience
   - **User action**: Swipes through pages and selects pain points

8. **Benefits Visualization** (`benefits_page_view.dart`)
   - **What happens**: Shows personalized benefits based on questionnaire answers:
     - Multiple benefit screens (rewire brain, level up life, conquer yourself, etc.)
     - Each benefit is visually presented with animations
   - **Purpose**: Shows users what they'll gain by quitting sugar (personalized to their goals)
   - **User action**: Swipes through benefit screens

9. **Science-Backed Plan** (`stoppr_science_backed_plan.dart`)
   - **What happens**: Explains Stoppr's methodology:
     - Based on behavioral science
     - Neuroscience of addiction
     - Habit formation principles
   - **Purpose**: Builds credibility and trust in the approach
   - **User action**: Reads and continues

10. **Goal Selection** (`choose_goals_onboarding.dart`)
    - **What happens**: Users select their primary goals from options like:
      - Weight loss
      - More energy
      - Better mental clarity
      - Improved health
      - Better self-control
      - etc.
    - **Purpose**: Sets user's primary motivation (used throughout app for reminders)
    - **User action**: Selects one or more goals

11. **Current vs Potential Rating** (`current_6_blocks_rating_screen.dart`, `potential_rating_screen.dart`)
    - **What happens**: 
      - First screen: Users rate themselves on 6 life areas (energy, mood, focus, etc.) - "Where are you now?"
      - Second screen: Shows potential ratings - "Where could you be?"
    - **Purpose**: Creates visual contrast between current state and potential future
    - **User action**: Rates themselves on multiple dimensions

12. **Weeks Progression** (`weeks_progression_screen.dart`)
    - **What happens**: Shows a visual timeline of expected progress:
      - Week 1: What to expect
      - Week 2-4: Milestones
      - Month 2-3: Long-term benefits
    - **Purpose**: Sets realistic expectations and shows the journey ahead
    - **User action**: Views timeline and continues

13. **Analysis Results** (`analysis_result_screen.dart`)
    - **What happens**: Displays personalized insights based on all questionnaire answers:
      - Sugar consumption analysis
      - Risk factors identified
      - Personalized recommendations
      - Expected benefits specific to their answers
    - **Purpose**: Shows users their personalized analysis (the "aha moment" that demonstrates value)
    - **User action**: Reviews their personalized results

14. **Give Us Ratings** (`give_us_ratings_screen.dart`)
    - **What happens**: Asks users to rate the app (optional)
    - **May show**: Soft paywall if user tries to skip
    - **Purpose**: Collects feedback and may show lighter paywall
    - **User action**: Rates app or continues

15. **Benefits Impact** (`benefits_impact_screen.dart`)
    - **What happens**: More detailed visualization of how quitting sugar will impact their specific life areas
    - **Purpose**: Reinforces the value proposition
    - **User action**: Views benefits and continues

16. **Letter from Future Self** (`letter_from_future_screen.dart`)
    - **What happens**: Users write a letter to their future self describing how their life will be better after quitting sugar
    - **Purpose**: Creates emotional connection and commitment (future self visualization)
    - **User action**: Writes a personal letter

17. **The Vow** (`read_the_vow_screen.dart`)
    - **What happens**: Users read and commit to "The Vow" - a commitment statement to quit sugar
    - **Purpose**: Creates a formal commitment ceremony (psychological commitment)
    - **User action**: Reads vow and commits

18. **Pre-Paywall Screen** (`pre_paywall.dart`) - **FIRST MAIN PAYWALL**
    - **What happens**: 
      - Shows "Become a STOPPR" button
      - Displays subscription benefits
      - May show discount offers
      - When user taps button, triggers Superwall paywall with placement `"standard_paywall"` or `"gift_step_1"`
    - **Purpose**: This is where users are asked to subscribe AFTER seeing all the value
    - **User action**: 
      - Subscribes → Goes to congratulations screens
      - Skips/Closes → Continues as free user with limited features

19. **Congratulations Screens** (`congratulations_screen_1.dart` through `congratulations_screen_8.dart`)
    - **What happens**: 8 sequential celebration screens:
      - Screen 1: Initial congratulations
      - Screen 2-7: Various motivational messages and next steps
      - Screen 8: Final welcome to the app
    - **Purpose**: Celebrates their commitment and transitions them into the main app
    - **User action**: Views celebration screens, then enters main app

**Paywall Locations in Onboarding**:
- **Main Paywall** (`pre_paywall.dart`): 
  - **When**: After completing entire questionnaire and seeing personalized analysis
  - **Trigger**: User taps "Become a STOPPR" button
  - **Superwall Placement**: `INSERT_YOUR_STANDARD_PAYWALL_PLACEMENT_ID_HERE` or `INSERT_YOUR_GIFT_STEP_1_PLACEMENT_ID_HERE` (⚠️ **Replace with your own placement IDs**)
  - **Why here**: Users have invested 10-15 minutes and seen personalized value
  
- **Soft Paywall** (`give_us_ratings_screen.dart`):
  - **When**: If user tries to skip rating step
  - **Trigger**: User attempts to skip
  - **Superwall Placement**: `INSERT_YOUR_SOFT_PAYWALL_PLACEMENT_ID_HERE` (⚠️ **Replace with your own placement ID**)
  - **Why here**: Lighter ask, doesn't interrupt main flow

- **Feature Paywalls** (Post-Onboarding):
  - Triggered when free users try to access premium features
  - Examples: Unlimited food scans, full panic button flow, all learn videos

#### 2. Home Screen (`home_screen.dart`)

**Overview**: The main screen users see after onboarding. Displays streak, widgets, and provides access to all app features.

**Main Components**:

**Top Section**:
- **Streak Counter Widget** (`streak_counter_widget.dart`): 
  - Real-time display of sugar-free days (updates every second)
  - Shows format like "2 DAYS 15 HRS 30 MIN" or "3 WEEKS 2 DAYS 4 HRS"
  - Large, prominent display
  - Tappable to edit streak or view details

- **Daily Check-In Widget** (`daily_check_in_widget.dart`):
  - Mood tracking with emoji selection
  - Users select how they're feeling (happy, neutral, sad, etc.)
  - Stores mood data for tracking patterns
  - May trigger motivational messages based on mood

- **Brain Rewiring Widget** (`brain_rewiring_widget.dart`):
  - Visual progress indicator showing "brain rewiring" progress
  - Based on days sugar-free and activities completed
  - Motivational visualization

- **Challenge Progress Widget** (`challenge_progress_widget.dart`):
  - 28-day challenge tracking
  - Shows completed days and tasks
  - Displays current challenge day

- **Goal Date Widget** (`goal_date_widget.dart`):
  - Countdown to goal achievement date
  - Based on user's selected goal from onboarding
  - Motivational countdown

- **Temptation Status Widget** (`temptation_status_widget.dart`):
  - Shows current state (tempted, strong, etc.)
  - Quick status indicator

- **Reason to Quit Widget** (`reason_to_quit_widget.dart`):
  - Displays user's primary reason from onboarding
  - Personalized motivation reminder

- **Weekly Tracker Widget** (`weekly_tracker_widget.dart`):
  - Visual progress chart for the week
  - Shows daily progress

- **Pledge Check-In Widget** (`pledge_check_in_widget.dart`):
  - Daily commitment verification
  - Users confirm they're staying committed
  - May show notifications if not checked in

- **Todo Challenge Widget** (`todo_challenge_widget.dart`):
  - Task-based challenges for the day
  - Examples: Journal entry, breathing exercise, meditation, food scan, etc.
  - Completing tasks unlocks rewards

**Bottom Navigation** (`main_scaffold.dart`):
The app has 5 main tabs accessible via bottom navigation:

1. **Home Tab** (Index 0): `HomeScreen` - Main dashboard with streak and widgets
2. **Learn Tab** (Index 1): `LearnVideoListScreen` - Educational videos
3. **Rewire Brain Tab** (Index 2): `HomeRewireBrainScreen` - Brain rewiring activities
4. **Community Tab** (Index 3): `CommunityScreen` - Social feed and chat
5. **Profile Tab** (Index 4): `UserProfileScreen` - User settings and profile

**Home Screen Menu Options** (Accessible via hamburger menu):

**Main Section**:
- **Add Widgets to Home**: Instructions for adding iOS/Android widgets to home screen
- **Accountability Partner**: Navigate to accountability partner feature
- **Calorie Tracker**: Opens calorie tracking dashboard
- **Food Scan**: Quick access to food scanning feature
- **Fasting**: Opens fasting tracking dashboard
- **Healthy Recipes**: Browse sugar-free recipes
- **Rate My Plate**: Meal analysis feature
- **Self Reflection**: Positive affirmations and reflection exercises
- **Talk to Jarvis**: AI chatbot for support
- **Chat**: Join community group chat
- **Leaderboard**: View community rankings
- **Achievements**: View unlocked achievements and milestones

**Mindfulness Section**:
- **Breathing Exercise**: Guided breathing animations
- **Success Stories**: User testimonials and success stories
- **Meditation Session**: Guided meditation sessions
- **Podcast**: Listen to health and wellness podcasts
- **Audio Library**: Collection of meditation and relaxation audio files
- **Articles**: Read educational articles about sugar addiction

**Misc Section**:
- **Games**: Links to distraction games (Gamezop) - helps users distract themselves during cravings
- **Tree of Life**: Visual progress tree that grows with streaks - motivational visualization
- **28-Day Challenge**: Full challenge screen with all tasks (see details below)
- **Journal**: Personal reflection journal entries

#### 2.1. Rewire Brain Tab (`home_rewire_brain.dart`)

**Overview**: Visual progress tracking showing "brain rewiring" progress over time. Based on neuroscience that it takes time to rewire neural pathways.

**Features**:
- **Two View Modes** (toggleable):
  - **Ring View**: Circular progress ring showing completion percentage
  - **Radar View**: Radar chart showing progress across multiple dimensions

- **Progress Calculation**:
  - Based on days sugar-free (from streak)
  - Target: 90 days for full "brain rewiring"
  - Shows percentage complete (e.g., "45% Complete")
  - Calculates completion date based on current progress

- **Weekly Check-In Tracker**:
  - Shows 7 days of the week
  - Tracks daily check-ins
  - Visual indicators for completed check-ins
  - Encourages daily engagement

- **Visual Elements**:
  - Animated progress rings/charts
  - Color changes as progress increases
  - Smooth animations when toggling views
  - Motivational messages based on progress

- **Integration**:
  - Links to pledge check-in
  - Connects to streak system
  - Shows target date for full rewiring

#### 2.2. 28-Day Challenge (`challenge_28_days_screen.dart`)

**Overview**: Structured 28-day challenge with daily tasks to help users build healthy habits and stay engaged.

**How It Works**:

**Challenge Structure**:
- **28 Days**: One task per day for 28 consecutive days
- **Random Task Distribution**: Tasks are randomly assigned to days (different for each user)
- **Daily Tasks**: Each day has one specific task to complete

**Available Task Types** (`challenge_service.dart`):
1. **Journal** (`taskTypeJournal`): Write a journal entry
2. **Breathing** (`taskTypeBreathing`): Complete a breathing exercise
3. **Pledge** (`taskTypePledge`): Make a daily pledge commitment
4. **Meditation** (`taskTypeMeditation`): Complete a meditation session
5. **Podcast** (`taskTypePodcast`): Listen to a podcast episode
6. **Articles** (`taskTypeArticles`): Read an educational article
7. **Food Scan** (`taskTypeFoodScan`): Scan a food item
8. **Rate My Plate** (`taskTypeRateMyPlate`): Rate a meal plate
9. **Chatbot** (`taskTypeChatbot`): Talk to Jarvis chatbot
10. **Community Post** (`taskTypeCommunityPost`): Create a community post
11. **Self Reflection** (`taskTypeSelfReflection`): Complete self-reflection exercise

**Challenge Screen Features**:
- **Day Display**: Shows current challenge day (1-28)
- **Task Card**: Displays today's task with description
- **Completion Status**: Visual indicator when task is completed
- **Progress Bar**: Shows overall challenge progress (X/28 days)
- **Calendar View**: Shows all 28 days with completion status
- **Task Navigation**: Tapping task navigates to relevant feature

**Starting the Challenge**:
- User can start challenge from home screen
- Challenge starts from day 1
- Tasks are randomly assigned at start
- Progress is saved locally and synced to Firestore

**Completing Tasks**:
- User completes task in relevant feature (e.g., completes breathing exercise)
- Challenge service detects completion
- Day is marked as complete
- Progress updates automatically
- Next day unlocks at midnight

**Rewards**:
- Achievement unlocked when challenge completed
- Visual celebration when finishing all 28 days
- May unlock special features or badges

#### 2.3. Rate My Plate (`rate_my_plate_scan_screen.dart`)

**Overview**: AI-powered meal analysis that rates how healthy a plate is for someone quitting sugar.

**How It Works**:

**Step 1: Photo Capture** (`rate_my_plate_scan_screen.dart`):
- User takes photo of their meal plate
- Camera interface with capture button
- Can retake photo if needed

**Step 2: AI Analysis**:
- **Groq Vision API** analyzes the image:
  - Identifies food items on plate
  - Estimates nutritional content
  - Evaluates sugar and carb content
  - Assesses protein, fats, vegetables

- **Analysis Criteria**:
  - **High Score (8-10)**: Plates with protein, healthy fats, vegetables, low carbs/sugar
  - **Mid Score (4-7)**: Balanced plates with some carbs
  - **Low Score (1-3)**: Plates dominated by high-carb or sugary foods

**Step 3: Results Display** (`rate_my_plate_results_screen.dart`):

**Rating Components**:
- **Overall Score**: 0-10 rating (higher = better for quitting sugar)
- **Title**: Summary of rating (e.g., "Excellent Low-Carb Plate!" or "Too Many Simple Carbs")
- **Description**: Detailed explanation of the rating
- **Strengths**: List of what's good about the plate
- **Improvements**: Suggestions for making it better
- **Nutritional Estimates**:
  - Estimated calories
  - Protein (grams)
  - Carbs (grams)
  - Fat (grams)
  - Sugar content (highlighted)
- **Carb Impact**: Description of how carbs affect blood sugar
- **Sugar Content**: Detailed sugar analysis
- **Protein Content**: Protein analysis

**Features**:
- **Share Results**: Share rating to social media
- **Save for Later**: Save plate rating to review
- **Try Again**: Rate another plate
- **Educational**: Helps users learn what makes a healthy plate

**Free vs Premium**:
- **Free users**: Limited ratings (e.g., 1 per day)
- **Premium users**: Unlimited ratings
- Paywall appears after free limit

#### 2.4. Food Scan (`food_scan_screen.dart`)

**Overview**: Camera-based food recognition using AI to identify foods and provide nutritional information.

**How It Works**:

**Step 1: Photo Capture**:
- User takes photo of food item
- Camera interface with capture button
- Can select from photo library

**Step 2: AI Recognition**:
- **OpenAI Vision API** analyzes image:
  - Identifies food items
  - Recognizes multiple foods in one image
  - Provides food names

**Step 3: Nutrition Lookup**:
- Searches Edamam Food Database for nutritional info
- **Fallback**: If Edamam fails, uses Spoonacular API
- Returns detailed nutrition:
  - Calories
  - Protein, carbs, fats
  - Sugar content (highlighted)
  - Fiber, sodium, etc.

**Step 4: Add to Log**:
- User confirms food identification
- Adjusts serving size if needed
- Adds to calorie tracker log
- Appears in daily food log

**Features**:
- **Quick Add**: Fast way to log foods without searching
- **Visual Recognition**: No need to type food names
- **Multiple Foods**: Can identify multiple items in one photo
- **Serving Size**: Adjustable portions

**Free vs Premium**:
- **Free users**: Limited scans (e.g., 1 scan per day)
- **Premium users**: Unlimited scans
- Paywall appears after free limit

#### 2.5. Self Reflection (`self_reflection.dart`)

**Overview**: Positive affirmations and reflection exercises to help users maintain motivation and self-awareness.

**Features**:
- **Daily Affirmations**: Positive messages tailored to user's goals
- **Reflection Prompts**: Questions to help users reflect on their journey
- **Emotional Tracking**: Track feelings and emotions
- **Progress Reflection**: Review progress and celebrate wins
- **Motivational Content**: Encouraging messages and quotes

#### 2.6. Talk to Jarvis (`chatbot_screen.dart`)

**Overview**: AI-powered chatbot assistant for support and guidance.

**Features**:
- **AI Chatbot**: Powered by OpenAI (or Groq as fallback)
- **24/7 Support**: Always available for questions
- **Personalized Responses**: Tailored to user's journey
- **Sugar Quitting Guidance**: Answers questions about quitting sugar
- **Motivational Support**: Provides encouragement when needed
- **Feature Information**: Explains how to use app features

**Use Cases**:
- Questions about sugar addiction
- Need for motivation
- Understanding app features
- General health questions
- Crisis support (complements panic button)

#### 3. Nutrition Tracking (Calorie Tracking)

**Overview**: Comprehensive calorie and nutrition tracking system to help users monitor their food intake and stay within sugar limits.

**How It Works**:

**Initial Setup** (`nutrition/presentation/onboarding/`):
1. **Goal Selection Screen** (`goal_selection_screen.dart`): User selects nutrition goals (weight loss, maintenance, muscle gain)
2. **Height & Weight Screen** (`height_weight_screen.dart`): Collects body measurements
3. **Workouts Per Week Screen** (`workouts_per_week_screen.dart`): Asks about exercise frequency
4. **Results Screen** (`results_screen.dart`): Calculates and displays:
   - Daily calorie goal (BMR + activity level)
   - Macronutrient breakdown (protein, carbs, fats)
   - Sugar limit recommendation (typically 50g or less)

**Main Dashboard** (`calorie_tracker_dashboard.dart`):

**Features**:
- **Day Selector**: Swipe through days to view past or future days
- **Daily Summary**: Shows:
  - Total calories consumed
  - Calories remaining
  - Macronutrients (protein, carbs, fats)
  - Sugar intake (with warning if over limit)
  - Water intake tracking
  - Net calories (after exercise)

- **Food Logs**: List of all foods logged for the day:
  - Each food shows calories, macros, and sugar content
  - Can edit or delete entries
  - Shows meal timing (breakfast, lunch, dinner, snack)

- **Add Meal Button**: Opens food entry screen

- **Progress Rings**: Visual indicators for:
  - Calorie progress
  - Protein, carbs, fats progress
  - Sugar limit (red warning if exceeded)

- **Water Tracker**: 
  - Track water intake by glasses/cups
  - Visual progress indicator
  - Customizable serving size

**Adding Foods** (`food_scanner_screen.dart`, `food_database_entry_screen.dart`):

**Method 1: Food Scanner** (Premium Feature):
1. User takes photo of food
2. OpenAI Vision API analyzes image
3. Identifies food items
4. Provides nutritional information
5. User confirms and adds to log
6. **Free users**: Limited scans (1 scan), paywall appears after limit

**Method 2: Food Database Search**:
1. User searches food database (Edamam API)
2. Selects food from results
3. Adjusts serving size
4. Adds to log
5. **Fallback**: If Edamam fails, automatically uses Spoonacular API

**Method 3: Manual Entry**:
1. User manually enters food name
2. Searches database
3. Selects and adds

**Additional Screens**:
- **Daily Breakdown** (`daily_breakdown_screen.dart`): Detailed view of daily nutrition by meal
- **Calorie Progress** (`calorie_progress_screen.dart`): 
  - Charts showing progress over time (90 days, 6 months, 1 year)
  - Weight tracking
  - BMI calculation
  - Goal progress visualization
- **Calorie Streak** (`calorie_streak_screen.dart`): Tracks consecutive days staying within calorie goals
- **Nutrition Goals** (`nutrition_goals_screen.dart`): Edit calorie and macro goals
- **Edit Weight/Height** (`edit_weight_screen.dart`, `edit_height_screen.dart`): Update body measurements
- **Exercise Logging** (`log_exercice/`):
  - **Run Exercise** (`run_exercise_setup_screen.dart`): Log running workouts
  - **Weight Lifting** (`weight_lifting_setup_screen.dart`): Log strength training
  - **Manual Exercise** (`manual_exercise_setup_screen.dart`): Log other exercises
  - **Exercise Type** (`exercise_type_screen.dart`): Choose exercise category
  - **Calorie Burned Result** (`calorie_burned_result_screen.dart`): Shows calories burned

**Sugar Tracking**:
- Tracks refined sugar intake separately
- Warns when approaching daily limit (default 50g)
- Shows popup if sugar limit exceeded
- Links to streak system (exceeding sugar may break streak)

**Data Storage**:
- Food logs stored in Firestore (`food_logs` collection)
- Daily summaries calculated and cached
- Body profile stored separately for calculations

#### 4. Community Features

**Overview**: Social features that create a supportive community for users quitting sugar together.

**Main Screens**:

**Community Screen** (`community_screen.dart`):
- **Posts Feed**: 
  - Scrollable feed of user-generated posts
  - Posts can include text, images
  - Shows author, timestamp, upvote count
  - Users can upvote posts they find helpful
  - Posts sorted by upvotes and recency

- **Add Post Button**: 
  - Opens `add_post_screen.dart`
  - Users can create new posts
  - Can include text and images
  - Posts are moderated

- **Post Details** (`post_detail_screen.dart`):
  - Full post view
  - Comments section
  - Users can comment on posts
  - View all comments and replies

**Chat Features**:

**Official Chat** (`official_chat_screen.dart`):
- **What it is**: AI-generated supportive messages
- **How it works**: 
  - Shows messages that appear to be from community members
  - Actually generated by AI (OpenAI) to provide constant support
  - Messages are encouraging and relevant to sugar quitting journey
  - Creates sense of active community even when real users aren't posting

**Language Chat** (`language_chat_screen.dart`):
- Chat filtered by user's language preference
- Ensures users see content in their language

**Community Rules** (`community_rules_screen.dart`):
- Guidelines for community participation
- Code of conduct
- What's allowed/not allowed

**Blocked Users** (`blocked_users_screen.dart`):
- Users can block other users
- Manage blocked list here

**Data Models**:
- **Post Model** (`post_model.dart`): Stores post data (text, images, author, timestamp, upvotes)
- **Comment Model** (`comment_model.dart`): Stores comments on posts
- **Chat Message Model** (`chat_message_model.dart`): Stores chat messages

**Repositories**:
- **Community Repository** (`community_repository.dart`): Handles post creation, fetching, upvoting
- **Chat Repository** (`chat_repository.dart`): Handles chat message operations

#### 5. Learn Section

**Overview**: Educational content to help users understand sugar addiction and build healthy habits.

**Video Lessons** (`learn_video_list_screen.dart`):

**Features**:
- **Video List**: Browseable collection of educational videos
- **Video Topics**: 
  - Welcome to Stoppr
  - Where is sugar hiding
  - Understanding cravings
  - Building healthy habits
  - Sugar is not a feelings fixer
  - Sport to fix your sugar life
  - Kill sugar peer pressure
  - And more...

- **Video Player** (`full_screen_video_player_screen.dart`):
  - Full-screen video playback
  - Play/pause controls
  - Progress bar
  - Subtitles support (multiple languages)
  - Volume controls
  - Can toggle subtitles on/off

- **Progress Tracking**:
  - Tracks which videos user has watched
  - Shows completion status
  - Unlocks next videos as user progresses

- **Free vs Premium**:
  - **Free users**: Limited to first video only
  - **Premium users**: Access to all videos
  - Paywall appears when free user tries to watch premium videos

**Articles** (`articles_list_screen.dart`):

**Features**:
- **Article List**: Browseable collection of educational articles
- **Article Topics** (20+ articles available):
  - Neuroscience of sugar addiction
  - Physical health consequences
  - Psychological effects
  - Natural vs added sugar
  - Sugar and gut health
  - Sugar and skin aging
  - Managing cravings triggers
  - Healthy coping mechanisms
  - And more...

- **Article Reader** (`article_detail_screen.dart`):
  - Markdown-based article viewing
  - Formatted text with headings, lists, etc.
  - Scrollable content
  - Can bookmark articles
  - Tracks reading progress

- **Multi-Language Support**:
  - Articles available in: English, French, Spanish, German, Italian, Russian, Czech, Slovak
  - Stored in `assets/articles/{language}/` directories
  - User sees articles in their app language

**Progress Tracking**:
- Tracks which articles user has read
- Shows reading progress
- May unlock achievements for reading all articles

#### 6. Panic Button Flow

**Overview**: Crisis intervention feature that provides immediate support when users feel tempted to consume sugar. The panic button guides users through a series of distraction techniques and coping strategies.

**How to Access**:
- Large red "PANIC" button on home screen
- Quick action from app icon (iOS/Android)
- Accessible from anywhere in the app

**Complete Flow Step-by-Step**:

**Step 1: What's Happening Screen** (`what_happening_screen.dart`)
- **What happens**: User taps panic button, sees screen asking "What's happening, [Name]?"
- **Purpose**: Acknowledges their struggle and creates pause
- **User action**: Taps "I need help" button
- **Next**: Goes to Tricks Intro Screen

**Step 2: Tricks Intro Screen** (`tricks_intro_screen.dart`)
- **What happens**: Explains that the app will show various "tricks" to help them resist
- **Purpose**: Sets expectations for the flow
- **User action**: Taps continue
- **Next**: Goes to first randomized trick

**Step 3-20: Randomized Trick Flow** (`panic_flow_manager.dart`)

**How Randomization Works**:
- `PanicFlowManager` creates a random order of 18 tricks
- First 17 tricks are shuffled randomly
- 18th trick (Sugary Treat) is always last
- Each user gets a different order each time they use panic button

**Available Tricks** (in random order):
1. **Drink Water** (`drink_glasses_water.dart`): Encourages drinking water to reduce cravings
2. **Eat Salty Food** (`eat_salty_screen.dart`): Suggests salty snacks to satisfy cravings
3. **Brush Teeth** (`brush_teeth_screen.dart`): Brushing teeth changes taste and creates barrier
4. **Drink Hot Tea** (`drink_hot_tea_screen.dart`): Warm beverage as distraction
5. **Dark Chocolate** (`dark_chocolate_screen.dart`): Small amount of dark chocolate (better than sugary treats)
6. **Exercise** (`exercise_screen.dart`): Physical activity to release endorphins
7. **High Protein** (`high_protein_screen.dart`): Protein-rich snack to feel full
8. **Fruits & Fiber** (`fruits_fiber_screen.dart`): Healthy fruit option
9. **Lemon Water** (`lemon_water_screen.dart`): Tart flavor to reduce cravings
10. **Cold Sparkling Water** (`cold_sparkling_water_screen.dart`): Carbonated water as alternative
11. **Step Burst** (`step_burst_screen.dart`): Quick burst of movement
12. **Visualization Script** (`visualization_script_screen.dart`): Guided visualization exercise
13. **Burpees** (`burpees_screen.dart`): High-intensity exercise
14. **Mint Gum** (`mint_gum_screen.dart`): Chewing gum for distraction
15. **Quick Nap** (`quick_nap_screen.dart`): Rest to reset mindset
16. **Apple Cider Vinegar** (`apple_cider_vinegar_screen.dart`): ACV drink suggestion
17. **Cold/Hot Shower** (`cold_hot_shower_screen.dart`): Temperature change to reset
18. **Games** (`games_screen.dart`): Distraction games
19. **Sugary Treat** (`sugary_treat_screen.dart`): **LAST RESORT** - If nothing else works, guides user to make better choice

**Flow Pattern** (After Each Trick):
- User sees trick screen with explanation
- User taps "I did it" or "Try something else"
- **After Trick 1**: Goes to "Feeling Now?" → "Try Something Else" → Next trick
- **After Trick 2**: Goes to "Feeling Now?" → Next trick directly
- **After Trick 3**: Goes to "Feeling Now?" → "Another Solution" → Next trick
- **After Trick 4**: Goes to "Feeling Now?" → "Other Trick" → Next trick
- **After Trick 5**: Goes to "Feeling Now?" → "Another Way" → Next trick
- **After Tricks 6-14**: Cycles through connector screens ("Try Something Else", "Another Solution", "Other Trick", "Another Way")
- **After Trick 18**: Goes to Congratulations Screen

**Connector Screens** (Between Tricks):
- **Feeling Now Screen** (`feeling_now_screen.dart`): Asks "How are you feeling now?" - checks if trick worked
- **Try Something Else Screen** (`try_something_else_screen.dart`): Encourages trying next trick
- **Another Solution Screen** (`another_solution_screen.dart`): Presents next trick as alternative solution
- **Other Trick Screen** (`other_trick_screen.dart`): Introduces next trick
- **Another Way Screen** (`another_way_screen.dart`): Suggests another approach

**Final Screen**:
- **Congratulations Screen** (`congratulations_screen.dart`): 
  - Celebrates user for getting through the panic moment
  - Shows supportive messages
  - Returns user to home screen

**Free vs Premium**:
- **Free users**: Limited to ~5 panic flow steps, then paywall appears
- **Premium users**: Full access to all 18 tricks and complete flow

**Data Tracking**:
- Tracks panic button usage (analytics)
- Records which tricks were shown
- May track which tricks are most effective

**Integration**:
- Links to breathing exercises
- May trigger notifications if user frequently uses panic button
- Connects to streak system (using panic button doesn't break streak, but giving in does)

#### 7. Accountability Partners

**Overview**: Users can pair up with accountability partners to support each other in quitting sugar.

**How It Works**:

**Accountability Partner Screen** (`accountability_partner_screen.dart`):

**If User Has No Partner**:
- **Find Partner Button**: 
  - Searches for available partners
  - Shows list of users looking for partners
  - User can send partner request

- **Invite Friend Button**:
  - Share app with friends via link
  - Friend can join and become partner
  - Uses referral system

- **Available Partners List** (`available_partners_list.dart`):
  - Shows users who are available to partner
  - Displays basic info (name, streak, etc.)
  - User can send request

**If User Has Partner**:
- **Partner Card** (`partner_card_widget.dart`):
  - Shows partner's name
  - Displays partner's current streak
  - Shows partner's mood (if shared)
  - Last active time

- **Partner Actions**:
  - View partner's detailed progress
  - Send messages (if enabled)
  - Unpair (end partnership)

**Partner Requests** (`partner_request_dialog.dart`):
- **Pending Requests** (`pending_request_card.dart`):
  - Shows incoming partner requests
  - User can accept or decline
  - Shows requester's info

- **Sent Requests**:
  - Shows requests user has sent
  - Can cancel pending requests

**Partnership Features**:
- **Shared Streaks**: See each other's streak progress
- **Mutual Support**: Encouragement when partner is struggling
- **Notifications**: Alerts when partner achieves milestones
- **Accountability**: Knowing someone is watching helps maintain commitment

**Unpairing** (`unpair_confirmation_dialog.dart`):
- User can end partnership
- Confirmation dialog to prevent accidental unpairing
- Both users notified when partnership ends

**Data Models**:
- **Accountability Partner** (`accountability_partner.dart`): Stores partner relationship data
- **Partnership** (`partnership.dart`): Tracks partnership status and details

#### 8. Streak Management

**Overview**: Core feature that tracks how many consecutive days users have been sugar-free. The streak is the primary motivation and progress indicator.

**How Streaks Work**:

**Streak Service** (`core/streak/streak_service.dart`):
- **Real-Time Tracking**: 
  - Streak counter updates every second
  - Calculates days, hours, minutes since last sugar consumption
  - Stored in Firestore and cached locally

- **Streak Calculation**:
  - Starts from user's "quit date" (set during onboarding or when they start)
  - Increments every day at midnight (user's timezone)
  - Breaks if user logs sugar consumption or relapse

- **Streak Display**:
  - Format: "2 DAYS 15 HRS 30 MIN" (for shorter streaks)
  - Format: "3 WEEKS 2 DAYS 4 HRS" (for longer streaks)
  - Updates in real-time on home screen

**Streak Features**:

**Edit Streak** (`home_edit_streak.dart`):
- Users can manually adjust streak if needed
- Useful for correcting errors or setting custom start date
- Requires confirmation to prevent accidental changes

**Streak Sharing** (`sharing_service.dart`):
- **Share to Social Media**:
  - Creates shareable image with streak count
  - Includes motivational message
  - Can share to Instagram, Facebook, Twitter, etc.
  - Helps users celebrate milestones publicly

**Achievements** (`achievements_service.dart`):
- **Unlockable Milestones**:
  - 1 day streak
  - 3 days streak
  - 1 week streak
  - 2 weeks streak
  - 1 month streak
  - 3 months streak
  - 6 months streak
  - 1 year streak
  - And more...

- **Achievement Screen** (`home_achievements.dart`):
  - View all unlocked achievements
  - See progress toward next achievement
  - Visual badges and rewards

**App Open Streak** (`app_open_streak_service.dart`):
- Tracks consecutive days user opens the app
- Separate from sugar-free streak
- Encourages daily engagement
- May show notifications if user hasn't opened app

**Streak Invites** (`accept_invite_page.dart`):
- Users can invite friends to track streaks together
- Creates shared streak challenge
- Both users see each other's progress

**Streak Widgets** (iOS/Android):
- **Home Screen Widgets**:
  - Shows current streak on device home screen
  - Updates automatically
  - Available for iOS and Android
  - Multiple widget sizes supported

**Relapse Handling**:
- If user logs sugar consumption, streak breaks
- **Relapse Flow** (`relapsed_flow/`):
  - **Why Screen** (`relapse_why_screen.dart`): Asks why they relapsed
  - **Help Worse Screen** (`relapse_help_worse_screen.dart`): Offers support
  - **Target Days Screen** (`relapse_target_days_screen.dart`): Sets new goal
  - **Signature Screen** (`relapse_signature_screen.dart`): Commits to restart
- After relapse, streak resets to 0
- User can start new streak immediately

#### 9. Meditation & Mindfulness

**Overview**: Mindfulness features to help users manage stress, cravings, and emotional triggers through meditation and breathing exercises.

**Meditation Screen** (`meditation_screen.dart`):

**Features**:
- **Guided Meditation Sessions**:
  - Pre-recorded meditation audio
  - Various lengths (5 min, 10 min, 15 min, 20 min)
  - Different themes (stress relief, sleep, focus, etc.)
  - Background music and guided voice

- **Meditation Library**:
  - Browse available meditations
  - Filter by duration, theme, or type
  - Track which meditations user has completed

- **Playback Controls**:
  - Play/pause
  - Skip forward/backward
  - Volume control
  - Progress indicator
  - Timer showing time remaining

**Breathing Exercises** (`breathing_exercise_screen.dart`, `breathing_animation_screen.dart`):

**Features**:
- **Guided Breathing Animations**:
  - Visual breathing guide (circle expands/contracts)
  - Follows breathing pattern (inhale, hold, exhale)
  - Various techniques:
    - 4-7-8 breathing (4 sec inhale, 7 sec hold, 8 sec exhale)
    - Box breathing (4-4-4-4)
    - Deep breathing
    - Calming breath

- **Panic Button Breathing** (`breathing_animation_screen.dart`):
  - Special breathing exercise accessible from panic button
  - Designed for moments of high stress/craving
  - Quick 2-3 minute sessions
  - Calming visuals and sounds

**Audio Library** (`audio_library_screen.dart`):

**Features**:
- **Collection of Audio Files**:
  - Meditation tracks
  - Nature sounds
  - White noise
  - Binaural beats
  - Relaxation music

- **Audio Player** (`audio_player_screen.dart`):
  - Full-featured audio player
  - Playlist support
  - Shuffle and repeat modes
  - Background playback (continues when app is minimized)
  - Lock screen controls

**Integration**:
- Accessible from home screen menu
- Part of panic button flow (breathing exercises)
- Can be scheduled via notifications
- Tracks usage for analytics

#### 10. Recipes

**Overview**: Browseable collection of healthy, sugar-free recipes to help users find meal alternatives.

**How It Works**:

**Recipe List Screen** (`recipes_list_screen.dart`):

**Features**:
- **Browse Recipes**: Scrollable list of recipes
- **Filters**:
  - **Calorie Range**: Filter by calories (e.g., 0-300, 300-600, 600+)
  - **Diet Type**: 
    - Vegetarian
    - Vegan
    - Gluten-free
    - Keto
    - Low-carb
    - etc.
  - **Meal Type**: Breakfast, Lunch, Dinner, Snack, Dessert

- **Search**: Search recipes by name or ingredients
- **Favorites**: Users can favorite recipes for quick access

**Recipe Details Screen** (`recipe_detail_screen.dart`):

**Information Displayed**:
- **Recipe Name**: Title of the recipe
- **Image**: High-quality food photo
- **Nutrition Info**:
  - Calories per serving
  - Protein, carbs, fats
  - Sugar content (highlighted)
  - Fiber, sodium, etc.
- **Ingredients List**: 
  - All ingredients with quantities
  - Can adjust serving size (ingredients scale automatically)
- **Instructions**: 
  - Step-by-step cooking instructions
  - Numbered steps
  - Clear directions
- **Serving Size**: Number of servings recipe makes
- **Prep Time**: How long to prepare
- **Cook Time**: How long to cook
- **Total Time**: Combined prep + cook time

**Recipe Repository** (`recipe_repository.dart`):

**API Integration**:
- **Primary**: Edamam Recipe API
  - Searches Edamam database
  - Filters for sugar-free/low-sugar recipes
  - Returns detailed nutrition and recipe data

- **Fallback**: Spoonacular Recipe API
  - **Used when Edamam fails**: If Edamam API call fails or times out, automatically retries with Spoonacular
  - Ensures recipe search always works
  - Same functionality as Edamam

**Recipe Favorites** (`recipe_favorites_repository.dart`):
- Users can save favorite recipes
- Stored in Firestore
- Quick access from favorites screen (`recipes_favorites_screen.dart`)
- Syncs across devices

**Widgets**:
- **Recipe Card** (`recipe_card.dart`): Displays recipe preview in list
- **Calorie Range Card** (`calorie_range_card.dart`): Filter widget for calories
- **Diet Filter Chip** (`diet_filter_chip.dart`): Filter widget for diet types
- **Meal Type Chip** (`meal_type_chip.dart`): Filter widget for meal types
- **Nutrition Info Card** (`nutrition_info_card.dart`): Shows nutrition breakdown

#### 11. Fasting Tracking

**Overview**: Intermittent fasting tracker to help users manage eating windows and track fasting periods.

**How It Works**:

**Setup Screen** (`fasting_setup_screen.dart`):
- First-time users see setup instructions
- Explains intermittent fasting concepts
- Guides users on how to use the feature

**Main Dashboard** (`fasting_dashboard_screen.dart`):

**Features**:
- **Active Fast Display**: 
  - Shows current fasting period if one is active
  - Real-time timer counting up
  - Progress ring showing completion percentage
  - Target duration (e.g., 16 hours, 12 hours)

- **Start Fast Button**: 
  - User taps to start a new fast
  - Can set target duration (defaults to common intervals like 12h, 16h, 18h, 24h)
  - Sets start time to current moment

- **Recent Fasts List**: 
  - Shows last 7 days of fasting activity
  - Each entry shows:
    - Start and end times
    - Duration achieved
    - Status (completed, active, cancelled)
  - Visual indicators for completed vs cancelled

- **Statistics**:
  - Current streak (consecutive days with completed fasts)
  - Longest fast duration
  - Fasts this week/month
  - Average fast duration

**Fast Management**:
- **Start Fast**: Creates new fast log with start time
- **End Fast**: User manually ends fast (or it auto-ends at target time)
- **Cancel Fast**: User can cancel an active fast
- **Edit Fast**: Can adjust start/end times for past fasts

**Notifications**:
- Motivational notifications scheduled at:
  - 4 hours before fast ends
  - 2 hours before fast ends
  - When fast completes
- Helps users stay motivated during fasting periods

**Data Storage**:
- Fast logs stored locally in SharedPreferences (not synced to Firestore)
- Each fast log contains:
  - Start time
  - End time (if completed)
  - Target duration
  - Actual duration
  - Status (active, completed, cancelled)
  - Milestone minutes (e.g., 12 hours = 720 minutes)

**Visual Progress**:
- Progress ring shows how far through current fast
- Color changes as progress increases
- Milestone markers (e.g., 12-hour mark)

**Integration**:
- Links to calorie tracker (fasting periods affect net calories)
- May affect streak if user breaks fast early with sugar consumption

#### 12. User Profile (`user_profile_screen.dart`)

**Overview**: User settings, profile management, and account features.

**Profile Tab** (Bottom Navigation Index 4):

**Main Sections**:

**Profile Information** (`user_profile_details.dart`):
- **Edit Profile**:
  - Name
  - Email
  - Age
  - Gender
  - Profile photo (optional)
- **Account Settings**:
  - Change password
  - Delete account option

**Notifications Settings** (`user_profile_notifications.dart`):
- **Push Notification Controls**:
  - Daily check-in reminders
  - Pledge check-in notifications
  - Streak milestone alerts
  - Motivational messages
  - Meal reminders
  - Fasting notifications
  - Community updates
- **Notification Timing**: Set preferred times for notifications
- **Do Not Disturb**: Quiet hours settings

**Subscription Management** (`cancel_subscription_screen.dart`):
- **View Subscription Status**:
  - Current plan (monthly, annual)
  - Renewal date
  - Subscription status (active, cancelled, expired)
- **Manage Subscription**:
  - Cancel subscription (via RevenueCat)
  - Change plan
  - Restore purchases
- **Billing History**: View past transactions

**Language Selection** (`language_selection_screen.dart`):
- Change app language
- Available languages: English, French, Spanish, German, Italian, Russian, Czech, Slovak, Chinese, Polish
- Changes take effect immediately
- Affects all app text and content

**More Options** (`more_screen.dart`):
- **Help & Support** (`user_profile_support.dart`):
  - Contact support (opens Crisp chat)
  - FAQ
  - Help articles
- **Give Feedback** (`give_feedback.dart`):
  - Rate the app
  - Submit feedback
  - Report bugs
- **About**: App version, terms, privacy policy

**Progress Card** (`progress_card.dart`):
- **Statistics Display**:
  - Total days sugar-free (all-time)
  - Current streak
  - Longest streak
  - Achievements unlocked
  - Challenges completed
- **Visual Progress**: Charts and graphs showing progress over time

**Journal** (`add_journal_entry.dart`, `journal_feelings.dart`):
- **Journal Entries**:
  - Users can write personal reflections
  - Track emotions and feelings
  - Record thoughts about their journey
  - Timestamped entries
- **Feelings Journal**:
  - Quick mood logging
  - Emotional state tracking
  - Patterns over time

**Achievements** (`home_achievements.dart`):
- View all unlocked achievements
- Progress toward next achievement
- Achievement categories:
  - Streak milestones
  - Challenge completions
  - Feature usage milestones
  - Community participation

**Meal Notifications** (`meal_notifications_screen.dart`):
- Configure meal reminder notifications
- Set meal times (breakfast, lunch, dinner)
- Reminders to log meals in calorie tracker

### Notification System - Smart Logic & Implementation Details

The notification system (`lib/core/notifications/notification_service.dart`) implements sophisticated logic to prevent spam, personalize messages, and respect user preferences. This section documents all the "smart" features that aren't immediately obvious.

#### 1. **Global Daily Cap & Spam Prevention**

**Daily Notification Limit**:
- **Maximum**: 3 notifications per day (`maxNotificationsPerDay = 3`)
- **Minimum Spacing**: 180 minutes (3 hours) between notifications (`minMinutesBetweenNotifications = 180`)
- **Purpose**: Prevents notification fatigue and ensures users aren't overwhelmed

**How It Works**:
- When scheduling a notification, the system checks:
  1. How many notifications have been scheduled today
  2. When the last notification was scheduled
  3. If the desired time is too close to the last notification, it automatically adjusts the time forward
  4. If the adjusted time would cross into the next day, the notification is skipped entirely
- **Timezone Handling**: Automatically resets counters if timezone offset changes (DST or manual changes)

**Exceptions** (bypass daily cap):
- **Fasting Motivational Notifications**: 4h, 2h, and completion reminders bypass the cap (high-priority)
- **App Update Notifications**: Scheduled separately at 9:12 PM, bypass cap
- **Accountability Partner Notifications**: Immediate push notifications (server-sent), outside daily cap

#### 2. **Subscription-Aware Messaging**

**Audience Types**:
- **Subscribers**: Get personalized, varied messages with day-based randomization
- **Non-Subscribers**: Get default messages encouraging subscription
- **Trial Users**: Get NO notifications at all during trial period

**How It Works**:
- Before scheduling, the system checks subscription status via RevenueCat
- Different message pools are used based on subscription status
- Subscribers get rotating messages (different each day), non-subscribers get static conversion-focused messages

#### 3. **State-Dependent Scheduling**

**RevenueCat & Superwall Integration**:
- Notifications wait for RevenueCat to be "ready" before scheduling
- If RevenueCat isn't ready during onboarding, scheduling is deferred and retried once when ready
- Prevents misclassifying trial users as subscribers

**One-Shot Retry Logic**:
- If scheduling fails due to RevenueCat not being ready, a flag is set
- When RevenueCat becomes ready, a one-time retry is executed
- Ensures notifications aren't lost due to race conditions

#### 4. **Localization & Multi-Language Support**

**Smart Caching**:
- Localized notification strings are cached per language
- Cache is invalidated when language changes
- Falls back to English if translation file is missing or corrupted

**Language Detection**:
- Reads app language from SharedPreferences (`app_language_code`)
- Loads appropriate JSON file from `assets/l10n/{languageCode}.json`
- All notification titles and bodies are translated based on user's language preference

**Text Sanitization**:
- All notification strings are sanitized before display to handle special characters and encoding issues

#### 5. **Personalization Features**

**Name Prefixing**:
- If user's first name is available, notifications are prefixed with localized greeting (e.g., "Hey [Name], ...")
- Name is fetched from Firestore `users` collection `firstName` field, or falls back to Auth `displayName`
- Falls back gracefully if name isn't available

**Day-Based Randomization**:
- Uses day-of-year as seed for random selection
- Ensures same message isn't shown twice on the same day
- Different users see different messages on the same day (true randomization)

#### 6. **Notification Types & Channels**

**Android Notification Channels** (allows users to mute specific types):
- `checkup_reminders_channel` - Daily pledge check-ins
- `streak_goals_channel` - Streak updates and achievements
- `morning_motivation_channel` - Morning motivational messages
- `app_update_channel` - App update announcements
- `chat_notifications_channel` - Community chat messages
- `marketing_offers_channel` - Special offers and deals
- `trial_offer_channel` - Trial offer notifications
- `time_sensitive_channel` - Important reminders (max importance)
- `meal_calorie_tracking_channel` - Food scan completion notifications
- `lunch_reminder_channel` - Lunch meal reminders
- `dinner_reminder_channel` - Dinner meal reminders
- `relapse_challenge_channel` - Relapse challenge daily notifications

**Notification IDs** (prevents duplicates):
- Each notification type has a unique ID
- Canceling and rescheduling uses the same ID to replace existing notifications

#### 7. **Permission Handling**

**Multi-Platform Support**:
- **iOS**: Requests alert, badge, and sound permissions separately
- **Android 13+**: Uses new notification permission API
- **Android <13**: Permissions granted automatically

**Permission State Tracking**:
- Checks system-level permissions before scheduling
- If system permissions are disabled, in-app toggles are automatically disabled
- Shows warning UI if user enables in-app but system permissions are off

**FCM Token Management**:
- FCM tokens are saved to Firestore `users/{uid}/fcmToken` for server-sent push notifications
- Token refresh is handled automatically
- Tokens are registered after permissions are granted (onboarding, settings, accountability partner)

#### 8. **Time-Based Scheduling**

**Configurable Times**:
- **Morning Motivation**: User-configurable time (default: 7:35 AM)
- **Checkup Reminders**: User-configurable time (default: 7:23 PM)
- **Meal Reminders**: User-configurable breakfast, lunch, dinner times

**Timezone Handling**:
- Uses `flutter_timezone` to detect user's local timezone
- All scheduled times are converted to user's local timezone
- Handles DST changes automatically

**Recurring Notifications**:
- Uses `matchDateTimeComponents` to schedule daily recurring notifications
- Automatically schedules for next day if time has already passed today

#### 9. **Onboarding-Specific Logic**

**Session Tracking**:
- Prevents duplicate permission requests during onboarding
- Tracks if permissions were already requested in current session
- Only schedules notifications once per onboarding flow

**Deferred Scheduling**:
- If RevenueCat isn't ready during onboarding, scheduling is deferred
- One-shot retry executes when RevenueCat becomes ready
- Prevents trial users from receiving subscriber notifications

#### 10. **Notification Payload & Navigation**

**Payload System**:
- Each notification includes a payload string identifying its type
- Payloads trigger specific navigation when tapped
- Non-paying users who tap notifications are redirected to paywall if they haven't subscribed

**Navigation Handling**:
- Payloads are stored in SharedPreferences for later processing
- Handles app state (foreground, background, terminated)
- Safely navigates using microtasks to avoid UI conflicts

#### 11. **Analytics Integration**

**Mixpanel Tracking**:
- All notification scheduling is tracked with Mixpanel
- Tracks notification taps with type and ID
- Includes audience type, scheduled time, and title in events

## Architecture

### Technology Stack

- **Framework**: Flutter 3.7.0+
- **Language**: Dart 3.7.0+
- **State Management**: BLoC (flutter_bloc) with Freezed for immutable states
- **Backend**: Firebase (Auth, Firestore, Storage, Analytics, Messaging, Functions)
- **Navigation**: GoRouter (via app/router.dart)
- **Localization**: flutter_localizations with JSON-based translations

### Third-Party Integrations

- **Superwall**: Paywall and subscription management
- **RevenueCat**: Cross-platform subscription handling
- **Mixpanel**: Analytics and user behavior tracking
- **Crisp**: Customer support chat
- **OpenAI**: Food recognition, chatbot, content generation
- **AppsFlyer**: Attribution and marketing analytics
- **Facebook App Events**: Meta/Facebook ad attribution and ROAS tracking (measures which Facebook ads drive subscriptions)
- **Mux**: Video hosting and streaming
- **SendGrid**: Email delivery
- **Groq**: AI inference (alternative to OpenAI)
- **Replicate**: AI model hosting
- **Edamam**: Nutrition database API
- **Spoonacular**: Recipe API
- **Gemini**: Google AI API

### Architecture Patterns

- **Feature-Based Structure**: Code organized by feature modules
- **Clean Architecture**: Separation of data, domain, and presentation layers
- **Repository Pattern**: Data access abstraction
- **Service Layer**: Business logic and external service integration
- **Cubit/Bloc**: State management for UI
- **Freezed**: Immutable data models with code generation

## Project Structure

```
lib/
├── app/                    # App-level configuration
│   ├── app.dart           # Main app widget
│   ├── router.dart        # Navigation configuration
│   └── theme/             # App theming
├── core/                   # Core functionality shared across features
│   ├── accountability/     # Accountability partner services
│   ├── analytics/          # Analytics services (Mixpanel, AppsFlyer)
│   ├── api_rate_limit/     # API rate limiting
│   ├── auth/               # Authentication (Firebase Auth)
│   ├── challenge/          # 28-day challenge logic
│   ├── chat/               # Crisp chat integration
│   ├── config/             # Environment configuration
│   ├── installation/       # Installation tracking
│   ├── journal/            # Journal service
│   ├── karma/              # Karma system
│   ├── localization/       # App localization
│   ├── models/             # Shared data models
│   ├── navigation/         # Navigation utilities
│   ├── notifications/      # Push notifications
│   ├── pledges/            # Daily pledge system
│   ├── pmf_survey/         # Product-market-fit surveys
│   ├── quick_actions/      # App icon quick actions
│   ├── relapse/            # Relapse tracking
│   ├── repositories/       # Shared repositories
│   ├── services/           # Core services
│   ├── streak/             # Streak tracking
│   ├── subscription/       # Subscription management
│   ├── superwall/          # Superwall integration
│   ├── tree/               # Tree of life feature
│   ├── usage/              # Feature quota management
│   ├── user/               # User attributes
│   └── utils/              # Utility functions
├── features/               # Feature modules
│   ├── accountability/     # Accountability partners
│   ├── app/                # Main app screens (home, profile, etc.)
│   ├── auth/               # Authentication screens
│   ├── community/          # Community features
│   ├── fasting/            # Fasting tracking
│   ├── learn/              # Learn section (videos, articles)
│   ├── nutrition/          # Nutrition tracking
│   ├── onboarding/         # Onboarding flow
│   ├── panic/              # Panic button
│   ├── recipes/            # Recipe features
│   ├── streak/             # Streak features
│   └── welcome/            # Welcome screen
├── firebase_options.dart   # Firebase configuration (generated)
├── main.dart               # App entry point
└── permissions/            # Permission handling

assets/
├── articles/               # Markdown articles by language
├── changelog/              # App changelog files
├── fonts/                  # Custom fonts (Elza Round)
├── images/                 # App images and assets
├── l10n/                   # Localization JSON files
├── sounds/                 # Audio files
├── subtitles/              # Video subtitles
└── videos/                 # Video assets

tools/                      # Development and deployment tools
├── apple-store-connect/    # App Store Connect scripts
├── firebase_cloud/         # Firebase Functions and scripts
├── l10n/                   # Localization tools
├── learn_articles/         # Article management scripts
├── learn_videos_subtitles/ # Subtitle processing
└── user_management/        # User management scripts

android/                    # Android-specific files
├── app/
│   ├── google-services.json  # Firebase config (needs generation)
│   └── build.gradle.kts      # Android build configuration
└── key.properties            # Signing keys (needs creation)

ios/                        # iOS-specific files
├── Runner/
│   ├── GoogleService-Info.plist  # Firebase config (needs generation)
│   └── Info.plist
└── exportOptions.plist      # App Store export options
```

## Prerequisites

**Quick Start Summary** (for experienced developers):
1. Clone repo → `flutter pub get` → `cd ios && pod install`
2. Copy all `.local` template files and fill in your values (see step 5 below)
3. Generate `firebase_options.dart` via `flutterfire configure`
4. Update Team ID in Xcode (step 5i)
5. Run `make reset-ios` then `make flutter-run-iphonex`

**Full Requirements** - Before setting up the project, ensure you have:

1. **Flutter SDK** (3.7.0 or higher)
   ```bash
   flutter --version
   ```

2. **Dart SDK** (included with Flutter)

3. **Firebase CLI**
   ```bash
   npm install -g firebase-tools
   firebase login
   ```

4. **FlutterFire CLI**
   ```bash
   dart pub global activate flutterfire_cli
   ```

5. **Xcode** (for iOS development on macOS)
   - Xcode 14.0 or higher
   - CocoaPods: `sudo gem install cocoapods`

6. **Android Studio** (for Android development)
   - Android SDK
   - Android SDK Platform 35
   - Android SDK Build-Tools 35.0.1
   - **Android Emulator**: Install via Android Studio
     - Open Android Studio → Tools → Device Manager → Create Device
     - Recommended: Pixel 4 or Pixel 6 Pro (similar size to iPhone XS)
     - Or via command line: `sdkmanager "system-images;android-35;google_apis;x86_64"` then create AVD

7. **Node.js** (for Firebase Functions and tools)
   ```bash
   node --version  # Should be 18.x or higher
   ```

8. **Git** for version control

## Setup Instructions

### 1. Clone the Repository

```bash
git clone <repository-url>
cd stoppr_app_public
```

### 2. Install Flutter Dependencies

```bash
flutter pub get
```

### 3. Install iOS Dependencies

```bash
cd ios
pod install
cd ..
```

### 4. Generate Code

The project uses code generation for Freezed models and JSON serialization:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 5. Set Up Configuration Files with Private Information

**⚠️ IMPORTANT**: This project uses `.local` template files for files containing private information. You **MUST** copy these templates and fill in your own values before the app will work.

**Quick Checklist** - Copy these `.local` files:
1. `.env.local` → `.env`
2. `ios/Runner/Info.plist.local` → `ios/Runner/Info.plist`
3. `ios/firebase_app_id_file.json.local` → `ios/firebase_app_id_file.json`
4. `ios/Runner/GoogleService-Info.plist.local` → `ios/Runner/GoogleService-Info.plist`
5. `android/app/google-services.json.local` → `android/app/google-services.json`
6. `android/app/src/main/res/values/strings.xml.local` → `android/app/src/main/res/values/strings.xml`
7. `ios/exportOptions.plist.local` → `ios/exportOptions.plist` (optional, only for release builds)

**Detailed instructions** for each file are below:

#### 5a. Set Up Environment Variables

Copy the `.env.local` template and fill in your values:

```bash
cp .env.local .env
```

Edit `.env` with your actual API keys and configuration (see [Configuration Guide](#configuration-guide)).

#### 5b. Set Up iOS Info.plist

Copy the `Info.plist.local` template and fill in your values:

```bash
cp ios/Runner/Info.plist.local ios/Runner/Info.plist
```

**What to replace in `Info.plist`**:
- **Google OAuth Client ID**: Replace `YOUR_GOOGLE_CLIENT_ID` with your Google OAuth client ID
  - **Where to find**: [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → Credentials → OAuth 2.0 Client IDs
  - **Format**: `123456789-abcdefghijklmnop.apps.googleusercontent.com`
  - **Also update**: The URL scheme `com.googleusercontent.apps.YOUR_GOOGLE_CLIENT_ID` in `CFBundleURLTypes`

- **Facebook App ID**: Replace `YOUR_FACEBOOK_APP_ID` with your Facebook App ID
  - **Where to find**: [Facebook Developers](https://developers.facebook.com/) → Your App → Settings → Basic → App ID
  - **Also update**: The URL scheme `fbYOUR_FACEBOOK_APP_ID` in `CFBundleURLTypes`

- **Facebook Client Token**: Replace `YOUR_FACEBOOK_CLIENT_TOKEN` with your Facebook Client Token
  - **Where to find**: [Facebook Developers](https://developers.facebook.com/) → Your App → Settings → Advanced → Security → Client Token
  - **⚠️ SENSITIVE**: Keep this secret, never commit it to version control

- **AppsFlyer Dev Key**: Replace `YOUR_APPSFLYER_DEV_KEY` with your AppsFlyer Dev Key
  - **Where to find**: [AppsFlyer Dashboard](https://hq1.appsflyer.com/) → Your App → Settings → App Settings → Dev Key
  - **⚠️ SENSITIVE**: Keep this secret

- **AppsFlyer App ID**: Replace `YOUR_APPSFLYER_APP_ID` with your AppsFlyer App ID
  - **Where to find**: [AppsFlyer Dashboard](https://hq1.appsflyer.com/) → Your App → Settings → App Settings → App ID

#### 5c. Set Up iOS Runner.entitlements

Copy the `Runner.entitlements.local` template and fill in your values:

```bash
cp ios/Runner/Runner.entitlements.local ios/Runner/Runner.entitlements
```

**What to replace in `Runner.entitlements`**:
- **Firebase Project ID in Associated Domains**: Replace `YOUR_FIREBASE_PROJECT_ID` with your Firebase project ID
  - **Location**: Line 13: `applinks:YOUR_FIREBASE_PROJECT_ID.firebaseapp.com`
  - **Example**: If your project ID is `my-app-12345`, change it to `applinks:my-app-12345.firebaseapp.com`
  - **Where to find**: 
    - Firebase Console → Project Settings → General → Project ID
    - Or: The project ID is visible in the Firebase Console URL: `https://console.firebase.google.com/project/YOUR_PROJECT_ID`
  - **Why needed**: Required for Firebase Dynamic Links and deep linking to work properly
  - **⚠️ IMPORTANT**: This file is tracked in git, so make sure to use your own Firebase project ID

**Note**: The other values in this file need to be updated for your app:
- Replace `applinks:stoppr.app` with your app's domain (e.g., `applinks:yourapp.com`)
- Replace `group.com.stoppr.app.shared` with your app group ID (e.g., `group.YOUR_BUNDLE_ID.shared`)

#### 5c.1. Set Up iOS StreakWidgetExtension.entitlements

Update the App Group identifier in `ios/StreakWidgetExtension.entitlements`:
- Replace `group.YOUR_BUNDLE_ID.shared` with your actual app group ID (e.g., `group.com.yourcompany.yourapp.shared`)
- This must match the app group ID used in `Runner.entitlements`

#### 5d. Set Up iOS Export Options

Copy the `exportOptions.plist.local` template and fill in your values:

```bash
cp ios/exportOptions.plist.local ios/exportOptions.plist
```

**What to replace in `exportOptions.plist`**:
- **Apple Developer Team ID**: Replace `YOUR_APPLE_DEVELOPER_TEAM_ID` with your Team ID
  - **Where to find**: 
    - [Apple Developer Portal](https://developer.apple.com/account/) → Membership section → Team ID
    - Or: Xcode → Preferences → Accounts → Select your Apple ID → Team ID column
  - **⚠️ SENSITIVE**: Keep this private

- **Provisioning Profile Names**: Replace the provisioning profile names with your own
  - **Main App**: Replace `YOUR_MAIN_APP_PROVISIONING_PROFILE_NAME` with your app's distribution provisioning profile name
  - **Widget Extension**: Replace `YOUR_WIDGET_PROVISIONING_PROFILE_NAME` with your widget's distribution provisioning profile name
  - **Where to find**:
    - Xcode → Preferences → Accounts → Select your Apple ID → Download Manual Profiles
    - Or: [Apple Developer Portal](https://developer.apple.com/account/resources/profiles/list) → Provisioning Profiles
    - Profile names are usually like: "App Store Distribution" or "iOS Distribution - Your Company Name"

**Note**: The `exportOptions.plist` file is only needed for building release/IPA files for App Store distribution. For development builds, you can skip this step initially.

#### 5d. Set Up Firebase Configuration Files

**Important**: Firebase configuration files contain project-specific credentials and must be generated from your Firebase Console.

**5d.1. Set Up Firebase App ID File**

Copy the `firebase_app_id_file.json.local` template and fill in your values:

```bash
cp ios/firebase_app_id_file.json.local ios/firebase_app_id_file.json
```

**What to replace in `firebase_app_id_file.json`**:
- **GOOGLE_APP_ID**: Replace `YOUR_GOOGLE_APP_ID` with your Firebase iOS app's Google App ID
  - **Where to find**: 
    - [Firebase Console](https://console.firebase.google.com/) → Your Project → Project Settings → Your iOS App → App ID
    - Format: `1:PROJECT_NUMBER:ios:APP_ID` (e.g., `1:123456789:ios:abcdef123456`)
  - **⚠️ SENSITIVE**: Contains Firebase project-specific identifiers

- **FIREBASE_PROJECT_ID**: Replace `YOUR_FIREBASE_PROJECT_ID` with your Firebase project ID
  - **Where to find**: 
    - [Firebase Console](https://console.firebase.google.com/) → Project Settings → General → Project ID
    - Or: The project ID is visible in the Firebase Console URL: `https://console.firebase.google.com/project/YOUR_PROJECT_ID`

**Note**: This file is automatically generated by FlutterFire CLI when you run `flutterfire configure`. If you're using FlutterFire CLI, you can skip this manual step as it will be generated automatically.

**5d.2. Set Up iOS Firebase Configuration (GoogleService-Info.plist)**

Copy the `GoogleService-Info.plist.local` template and fill in your values:

```bash
cp ios/Runner/GoogleService-Info.plist.local ios/Runner/GoogleService-Info.plist
```

**What to replace in `GoogleService-Info.plist`**:
- **CLIENT_ID**: Your Google OAuth Client ID (from Firebase Console → Your iOS App → OAuth clients)
- **REVERSED_CLIENT_ID**: Same as CLIENT_ID but reversed format
- **API_KEY**: Firebase API Key (from Firebase Console → Your iOS App → API Key)
- **GCM_SENDER_ID**: Firebase GCM Sender ID (usually your Project Number)
- **BUNDLE_ID**: Your app's bundle identifier (should match Xcode)
- **PROJECT_ID**: Your Firebase Project ID
- **STORAGE_BUCKET**: Your Firebase Storage Bucket (format: `PROJECT_ID.firebasestorage.app`)
- **GOOGLE_APP_ID**: Your Google App ID (format: `1:PROJECT_NUMBER:ios:APP_ID`)

**Where to find**: All values are available in [Firebase Console](https://console.firebase.google.com/) → Your Project → Project Settings → Your iOS App

**5d.3. Set Up Android Firebase Configuration (google-services.json)**

Copy the `google-services.json.local` template and fill in your values:

```bash
cp android/app/google-services.json.local android/app/google-services.json
```

**What to replace in `google-services.json`**:
- **project_number**: Your Firebase Project Number
- **project_id**: Your Firebase Project ID
- **storage_bucket**: Your Firebase Storage Bucket
- **mobilesdk_app_id**: Your Android App ID (format: `1:PROJECT_NUMBER:android:APP_ID`)
- **package_name**: Your Android package name (should be `com.stoppr.sugar.app`)
- **oauth_client**: OAuth Client IDs (Android and Web)
- **certificate_hash**: SHA-1 certificate hash (for Android OAuth)
- **api_key**: Firebase API Key

**Where to find**: All values are available in [Firebase Console](https://console.firebase.google.com/) → Your Project → Project Settings → Your Android App

**Note**: The easiest way to get these files is to download them directly from Firebase Console:
- iOS: Firebase Console → Your iOS App → Download `GoogleService-Info.plist`
- Android: Firebase Console → Your Android App → Download `google-services.json`

#### 5e. Set Up StoreKit Configuration File (Products.storekit)

The `Products.storekit` file is used for testing in-app purchases and subscriptions in the iOS Simulator without needing real App Store Connect products. This allows you to test subscription flows, purchases, and paywall functionality locally.

**Why it's needed**:
- Test in-app purchases without App Store Connect approval
- Test subscription flows (monthly, annual, trials) locally
- Test paywall functionality during development
- No need to create real products in App Store Connect for testing

**How to generate it**:

**Option 1: Create via Xcode (Recommended)**:
1. Open `ios/Runner.xcworkspace` in Xcode
2. In Xcode, go to **File → New → File...**
3. Select **StoreKit Configuration File** (under iOS → Other)
4. Name it `Products.storekit` and save it in `ios/Runner/` directory
5. In the StoreKit Configuration editor:
   - Click the **+** button to add products
   - Add your subscription products:
     - **Product ID**: `com.stoppr.app.monthly` (Monthly Subscription)
     - **Type**: Auto-Renewable Subscription
     - **Price**: $14.99
     - **Subscription Period**: 1 Month
   - Add more products as needed (annual, lifetime, etc.)
   - Configure subscription groups if needed

**Option 2: Copy from template** (if provided):
```bash
# If a Products.storekit.local template exists, copy it:
cp ios/Runner/Products.storekit.local ios/Runner/Products.storekit
# Then edit it in Xcode to match your product IDs
```

**Product IDs used in this app** (add these to your StoreKit config):
- `com.stoppr.app.monthly` - Monthly subscription ($14.99/month)
- `com.stoppr.app.annual` - Annual subscription ($49.99/year)
- `com.stoppr.app.annual.trial` - Annual with 3-day trial
- `com.stoppr.app.annual80OFF` - Annual with 80% discount ($19.99/year)
- `com.stoppr.lifetime` - Lifetime purchase ($79.99 one-time)
- `com.stoppr.weekly_cheap.app` - Weekly subscription (Youth pricing)
- `com.stoppr.monthly_cheap.app` - Monthly subscription (Youth pricing)
- `com.stoppr.annual_cheap.app` - Annual subscription (Youth pricing)
- And more (see `ios/Runner/Products.storekit` for complete list)

**How to use it**:
1. In Xcode, select your scheme (Runner)
2. Go to **Product → Scheme → Edit Scheme...**
3. Select **Run** → **Options** tab
4. Under **StoreKit Configuration**, select `Products.storekit`
5. Now when you run the app in the simulator, StoreKit will use this configuration for testing purchases

**Note**: The StoreKit configuration file is only used for local testing. For production builds, the app uses real products from App Store Connect configured via RevenueCat.

#### 5f. Set Up Firebase Configuration File (`firebase.json`)

**⚠️ IMPORTANT**: `firebase.json` contains project-specific configuration and is not committed to git. You need to create it from the template.

**How to set up**:

1. Copy the template file:
   ```bash
   cp firebase.json.local firebase.json
   ```

2. Update `firebase.json` with your Firebase project details:
   - Replace `YOUR_PROJECT_ID` with your Firebase project ID
   - Replace `YOUR_IOS_APP_ID` with your iOS app ID from Firebase Console
   - Replace `YOUR_ANDROID_APP_ID` with your Android app ID from Firebase Console
   - Or regenerate via `firebase init` if starting fresh

**Note**: The `.local` file is a template. The actual `firebase.json` file is gitignored and should contain your project-specific configuration.

#### 5g. Update Firebase Project ID in Configuration Files

Several files contain the Firebase project ID (`stoppr-f2d4a`) which needs to be updated if you're using a different Firebase project:

**Files that need updating**:

1. **`firebase.json`** (see step 5f above):
   - Contains `projectId: "stoppr-f2d4a"` and app IDs
   - **Action**: Update with your Firebase project ID and app IDs
   - **How**: Edit the file directly or regenerate via `firebase init`

2. **`ios/Runner/Runner.entitlements`** (see step 5c above):
   - Contains associated domain: `applinks:YOUR_FIREBASE_PROJECT_ID.firebaseapp.com`
   - **Action**: Replace `YOUR_FIREBASE_PROJECT_ID` with your Firebase project ID
   - **⚠️ IMPORTANT**: This file is tracked in git, so make sure to use your own Firebase project ID
   - **How**: 
     - Open `ios/Runner.xcworkspace` in Xcode
     - Select Runner target → Signing & Capabilities → Associated Domains
     - Update `applinks:YOUR_PROJECT_ID.firebaseapp.com`

3. **`Makefile`**:
   - Contains `firebase use stoppr-f2d4a` and cloud function URLs with project ID
   - **Action**: Replace `stoppr-f2d4a` with your Firebase project ID in:
     - Line 543: `firebase use YOUR_PROJECT_ID`
     - Line 553: Cloud function URL: `https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/stripeWebhook`
   - **How**: Edit `Makefile` directly and replace all occurrences of `stoppr-f2d4a` with your project ID

4. **`ios/Runner/GoogleService-Info.plist`** (if using template):
   - Contains `PROJECT_ID` and `STORAGE_BUCKET` with project ID
   - **Action**: Already handled in step 5d (Firebase App ID File setup)

4. **`android/app/google-services.json`** (if using template):
   - Contains `project_id` and `storage_bucket` with project ID
   - **Action**: Already handled in step 5d (Firebase App ID File setup)

**Note**: These files are configuration files that reference your Firebase project. They're less sensitive than API keys but should still be updated to match your Firebase project.

#### 5h. Set Up Android String Resources

Copy the `strings.xml.local` template and fill in your values:

```bash
cp android/app/src/main/res/values/strings.xml.local android/app/src/main/res/values/strings.xml
```

**What to replace in `strings.xml`**:
- **facebook_app_id**: Replace `YOUR_FACEBOOK_APP_ID` with your Facebook App ID
  - **Where to find**: [Facebook Developers](https://developers.facebook.com/) → Your App → Settings → Basic → App ID
- **facebook_client_token**: Replace `YOUR_FACEBOOK_CLIENT_TOKEN` with your Facebook Client Token
  - **Where to find**: [Facebook Developers](https://developers.facebook.com/) → Your App → Settings → Advanced → Security → Client Token
  - **⚠️ SENSITIVE**: Keep this secret, never commit it to version control

**Note**: If you have multiple language variants (values-cs, values-de, etc.), you'll need to copy the template to each directory and update the Facebook credentials in each file.

#### 5h.1. Update App Store ID in Localization Files

The app's localization files (`assets/l10n/*.json`) contain references to the App Store ID in accountability partner invitation messages. You need to replace the placeholder with your actual App Store ID:

**What to replace**:
- Search for `INSERT_YOUR_APP_STORE_ID_HERE` in all `assets/l10n/*.json` files
- Replace with your actual App Store ID (e.g., `6742406521`)
- **Where to find**: Your App Store Connect → App Information → Apple ID

**Files to update**:
- `assets/l10n/en.json`
- `assets/l10n/fr.json`
- `assets/l10n/es.json`
- `assets/l10n/de.json`
- `assets/l10n/it.json`
- `assets/l10n/pl.json`
- `assets/l10n/cs.json`
- `assets/l10n/ru.json`
- `assets/l10n/sk.json`
- `assets/l10n/zh.json`

**Quick command** (if you have your App Store ID):
```bash
find assets/l10n -name "*.json" -type f -exec sed -i '' 's/INSERT_YOUR_APP_STORE_ID_HERE/YOUR_ACTUAL_APP_STORE_ID/g' {} \;
```

**⚠️ Note**: The repository contains placeholder `INSERT_YOUR_APP_STORE_ID_HERE` instead of a real App Store ID. This appears in accountability partner invitation messages that include download links.

#### 5i. Update Xcode Project Team ID

After setting up `Info.plist` and `exportOptions.plist`, you also need to update the Team ID in the Xcode project:

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the **Runner** project in the navigator (top item)
3. Select the **Runner** target
4. Go to the **Signing & Capabilities** tab
5. Under **Team**, select your Apple Developer Team (or add your Apple ID if not already added)
6. Xcode will automatically update the Team ID (`DEVELOPMENT_TEAM`) in `project.pbxproj`

**Alternative**: If you prefer to update manually, search for `INSERT_YOUR_APPLE_DEVELOPER_TEAM_ID_HERE` in `ios/Runner.xcodeproj/project.pbxproj` and replace all occurrences with your Team ID.

**⚠️ Note**: The repository contains placeholder `INSERT_YOUR_APPLE_DEVELOPER_TEAM_ID_HERE` instead of a real Team ID. You must replace this with your own Apple Developer Team ID.

### 6. Set Up Firebase (Additional Configuration)

**Note**: Most Firebase configuration is handled in step 5d above. This section covers additional Firebase setup.

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Add iOS and Android apps to your Firebase project
3. Follow the [Config Files Generation](#config-files-generation) section to generate required Firebase files

### 7. Verify Setup Checklist

Before running the app, ensure you have completed all required setup steps:

**Required Setup**:
- [ ] ✅ Copied `.env.local` → `.env` and filled in all API keys
- [ ] ✅ Copied `ios/Runner/Info.plist.local` → `ios/Runner/Info.plist` and filled in values
- [ ] ✅ Copied `ios/firebase_app_id_file.json.local` → `ios/firebase_app_id_file.json` (or generated via FlutterFire CLI)
- [ ] ✅ Copied `ios/Runner/GoogleService-Info.plist.local` → `ios/Runner/GoogleService-Info.plist` and filled in values
- [ ] ✅ Copied `android/app/google-services.json.local` → `android/app/google-services.json` and filled in values
- [ ] ✅ Copied `android/app/src/main/res/values/strings.xml.local` → `android/app/src/main/res/values/strings.xml` and filled in Facebook credentials
- [ ] ✅ Generated `lib/firebase_options.dart` via FlutterFire CLI
- [ ] ✅ Updated Team ID in Xcode project settings (step 5i) - replaced `INSERT_YOUR_APPLE_DEVELOPER_TEAM_ID_HERE` placeholder
- [ ] ✅ Updated Firebase project ID in `firebase.json` and `ios/Runner/Runner.entitlements` (step 5f)
- [ ] ✅ Updated App Store ID in localization files (step 5h.1) - replaced `INSERT_YOUR_APP_STORE_ID_HERE` placeholder
- [ ] ✅ Updated Google OAuth Client IDs in `.env` or `auth_service.dart` (replaced placeholder fallbacks)
- [ ] ✅ Installed iOS Simulator (comes with Xcode, verify in Xcode → Preferences → Components)

**Optional but Recommended**:
- [ ] Created `ios/Runner/Products.storekit` for testing purchases (step 5e)
- [ ] Copied `ios/exportOptions.plist.local` → `ios/exportOptions.plist` (only needed for release builds)
- [ ] Set up Android Emulator (via Android Studio, for Android testing)

### 8. Configure iOS

1. **Update Team ID** (if not done in step 5i):
   - Open `ios/Runner.xcworkspace` in Xcode
   - Select the **Runner** project → **Runner** target → **Signing & Capabilities** tab
   - Select your Apple Developer Team under **Team**
   - Xcode will automatically update the Team ID in the project

2. **Verify Bundle Identifier**:
   - Ensure bundle identifier (`com.stoppr.app`) matches your Firebase configuration
   - If using a different bundle ID, update it in:
     - Xcode: Runner target → General → Bundle Identifier
     - Firebase Console: iOS app settings
     - `Info.plist`: `CFBundleIdentifier` (if hardcoded)

3. **Verify Signing**:
   - Ensure "Automatically manage signing" is enabled (recommended for development)
   - Or use manual signing with your provisioning profiles (required for distribution)

4. **Set Up StoreKit Configuration** (for testing purchases):
   - In Xcode, select your scheme (Runner)
   - Go to **Product → Scheme → Edit Scheme...**
   - Select **Run** → **Options** tab
   - Under **StoreKit Configuration**, select `Products.storekit` (if you created it in step 5e)

### 9. Install Simulators for Testing

#### iOS Simulator

**iOS Simulator comes with Xcode** - no separate installation needed!

**To verify simulators are installed**:
1. Open Xcode
2. Go to **Xcode → Preferences → Components** (or **Settings → Platforms** in newer Xcode)
3. Check that iOS simulators are listed and downloaded

**To install additional iOS versions**:
1. In Xcode → Preferences → Components
2. Click the **+** button next to desired iOS version
3. Wait for download to complete

**Or via command line**:
```bash
# List available simulators
xcrun simctl list devices

# Download a specific iOS platform (if needed)
xcodebuild -downloadPlatform iOS
```

**Recommended simulators for testing**:
- **iPhone XS** (matches iPhone X size) - Use `make flutter-run-iphonex`
- **iPhone 15 Pro** - Use `make flutter-run-iphone15-pro`
- **iPhone 16** - Use `make flutter-run-iphone16`

#### Android Emulator

**Install via Android Studio**:
1. Open Android Studio
2. Go to **Tools → Device Manager**
3. Click **Create Device**
4. Select a device (recommended: **Pixel 4** or **Pixel 6 Pro** - similar size to iPhone XS)
5. Select a system image (recommended: **API 35** or latest)
6. Click **Finish** to create the emulator

**Or verify existing emulators**:
```bash
# List available emulators (if Android SDK is installed)
$ANDROID_SDK_ROOT/emulator/emulator -list-avds
```

**Recommended Android emulators**:
- **Pixel 4** (similar size to iPhone XS) - Use `make flutter-run-android-xs`
- **Pixel 6 Pro** - Use `make flutter-run-android-pixel6pro`

**Note**: Android emulator setup is optional if you're only testing on iOS. The app works on both platforms, but iOS testing is sufficient for most development.

### 10. Configure Android

1. Open the project in Android Studio
2. Ensure `package_name` in `android/app/build.gradle.kts` matches Firebase configuration
3. Set up signing keys (see [Config Files Generation](#config-files-generation))

## Configuration Guide

### Environment Variables

The app uses environment variables stored in `.env` file (which should be in `.gitignore`). See `.env.local` for a template with all required variables.

#### Required Environment Variables

**Superwall (Paywall & Subscription Management)**
- `SUPERWALL_IOS_API_KEY`: Superwall public API key for iOS
- `SUPERWALL_ANDROID_API_KEY`: Superwall public API key for Android
- **Why needed**: Superwall is the paywall platform that displays subscription options to users. It handles the entire paywall presentation, A/B testing, and conversion tracking.
- **What the app does**: 
  - Shows paywalls at strategic points (after onboarding, when accessing premium features)
  - Tracks which paywall designs convert best
  - Manages subscription status and unlocks premium features
  - Handles paywall dismissals and purchases
- **Where it's used**: `lib/features/onboarding/presentation/screens/pre_paywall.dart` (main paywall), `give_us_ratings_screen.dart` (soft paywall), and throughout the app for feature-gated content
- Get from: [Superwall Dashboard](https://superwall.com/dashboard)

**⚠️ IMPORTANT: Superwall Placement IDs**

The codebase contains placeholder strings for Superwall placement IDs (e.g., `INSERT_YOUR_STANDARD_PAYWALL_PLACEMENT_ID_HERE`). **You MUST replace these with your own placement IDs** from your Superwall dashboard before the app will work correctly.

**Required Placement IDs** (search the codebase for these placeholders):
- `INSERT_YOUR_STANDARD_PAYWALL_PLACEMENT_ID_HERE` - Main paywall shown after onboarding and for premium features
- `INSERT_YOUR_GIFT_STEP_1_PLACEMENT_ID_HERE` - Gift paywall variant (step 1)
- `INSERT_YOUR_GIFT_STEP_2_PLACEMENT_ID_HERE` - Gift paywall variant (step 2)
- `INSERT_YOUR_SOFT_PAYWALL_PLACEMENT_ID_HERE` - Soft paywall shown during onboarding
- `INSERT_YOUR_X_TAP_PLACEMENT_ID_HERE` - Paywall triggered when user taps X to dismiss
- `INSERT_YOUR_NOTIFICATION_TRIAL_PLACEMENT_ID_HERE` - Paywall triggered from notification trial payload
- `INSERT_YOUR_REDOWNLOAD_80_OFF_PLACEMENT_ID_HERE` - Paywall for redownload feedback flow
- `INSERT_YOUR_QUICK_ACTIONS_80OFF_PLACEMENT_ID_HERE` - Paywall for quick actions

**How to set up Superwall Placements**:

1. **Create placements in Superwall Dashboard**:
   - Go to [Superwall Dashboard](https://superwall.com/dashboard) → Your Project → Placements
   - Create placements with the names you want (e.g., `standard_paywall`, `gift_step_1`, etc.)
   - Configure each placement with your paywall designs and A/B tests

2. **Replace placeholders in code**:
   - Search the codebase for `INSERT_YOUR_*_PLACEMENT_ID_HERE`
   - Replace each placeholder with your actual placement ID from Superwall
   - **Example**: Replace `INSERT_YOUR_STANDARD_PAYWALL_PLACEMENT_ID_HERE` with `standard_paywall` (or whatever you named it in Superwall)

3. **Files that contain placement IDs** (search and replace in these files):
   - `lib/features/onboarding/presentation/screens/pre_paywall.dart`
   - `lib/main.dart`
   - `lib/features/app/presentation/screens/home_screen.dart`
   - `lib/features/app/presentation/screens/chatbot/chatbot_screen.dart`
   - `lib/features/onboarding/presentation/screens/give_us_ratings_screen.dart`
   - `lib/features/onboarding/presentation/screens/redownload_feedback_screen.dart`
   - `lib/core/quick_actions/quick_actions_service.dart`
   - `lib/features/app/presentation/screens/food_scan/food_scan_screen.dart`
   - `lib/features/app/presentation/screens/rate_my_plate/rate_my_plate_scan_screen.dart`
   - `lib/features/app/presentation/screens/food_scan/food_alternatives_screen.dart`
   - `lib/features/learn/presentation/screens/learn_video_list_screen.dart`
   - `lib/core/analytics/superwall_utils.dart`

**Note**: If you don't have all these placements set up yet, you can:
- Use the same placement ID for multiple locations (e.g., use `standard_paywall` everywhere)
- Create minimal placements first and expand later
- Comment out placement registrations you don't need yet

**Without valid placement IDs, paywalls will not display correctly and the app may crash or show errors.**

**RevenueCat (Cross-Platform Subscription Backend)**
- `REVENUECAT_IOS_API_KEY`: RevenueCat public API key for iOS
- `REVENUECAT_ANDROID_API_KEY`: RevenueCat public API key for Android
- `REVENUECAT_PRIVATE_API_KEY`: RevenueCat private API key (for server-side)
- **Why needed**: RevenueCat manages subscriptions across iOS and Android, handles receipt validation, and provides a unified subscription status API.
- **What the app does**:
  - Validates subscription purchases with Apple/Google
  - Syncs subscription status across devices
  - Handles subscription renewals and cancellations
  - Provides subscription status to Superwall for paywall logic
- **Where it's used**: `lib/core/subscription/subscription_service.dart` - checks if user has active subscription
- Get from: [RevenueCat Dashboard](https://app.revenuecat.com/)

**Mixpanel (User Analytics & Behavior Tracking)**
- `MIXPANEL_API_KEY`: Mixpanel project token
- `MIXPANEL_USERNAME`: Mixpanel service account username
- `MIXPANEL_SECRET`: Mixpanel service account secret
- **Why needed**: Mixpanel tracks user behavior, events, and funnels to understand how users interact with the app.
- **What the app does**:
  - Tracks screen views (e.g., "Onboarding Progress Card Creation Screen: Page Viewed")
  - Tracks button taps (e.g., "Onboarding Progress Card Creation Screen: Button Tap")
  - Tracks user actions (food scans, panic button usage, streak milestones)
  - Creates funnels to analyze onboarding completion rates
  - Tracks subscription conversion events
- **Where it's used**: `lib/core/analytics/mixpanel_service.dart` - called throughout the app for event tracking
- Get from: [Mixpanel Settings](https://mixpanel.com/settings/project)

**Facebook App Events (Meta Analytics & Ad Attribution)**
- `FacebookAppID`: Facebook App ID (configured in `Info.plist` and `strings.xml`)
- `FacebookClientToken`: Facebook Client Token (configured in `Info.plist` and `strings.xml`)
- **Why needed**: Facebook App Events tracks user actions and purchases for Facebook/Meta ad attribution and ROAS (Return on Ad Spend) measurement. This allows the app to measure which Facebook ads are driving subscriptions and optimize ad spend.
- **What the app does**:
  - **Purchase Tracking**: Tracks `fb_mobile_purchase` events when users subscribe (for measuring ad ROI)
  - **Subscription Events**: Tracks `Subscribe` events when users start paid subscriptions
  - **Trial Events**: Tracks `StartTrial` events when users begin free trials (via Meta CAPI/Cloud Functions)
  - **Checkout Initiation**: Tracks `fb_mobile_initiated_checkout` when users tap subscribe buttons (to measure funnel conversion)
  - **Trial Conversion**: Tracks trial-to-paid conversions for ROAS calculation
  - **Ad Attribution**: Helps Facebook attribute app installs and purchases to specific ad campaigns
  - **ROAS Optimization**: Provides data to optimize Facebook ad campaigns and improve cost per acquisition
- **Where it's used**: 
  - `lib/core/superwall/superwall_purchase_controller.dart` - tracks purchase, subscription, and trial conversion events
  - `lib/features/onboarding/presentation/screens/pre_paywall.dart` - tracks checkout initiation events
  - Facebook SDK is initialized in `main.dart` and configured via `Info.plist` (iOS) and `strings.xml` (Android)
- **Note**: Facebook tracking is gated by gender (skips tracking for known male users) to optimize ad targeting. This is a business optimization, not a technical requirement.
- Get from: [Facebook Developers Console](https://developers.facebook.com/) → Your App → Settings → Basic (App ID) and Advanced → Security (Client Token)

**Crisp (Customer Support Chat)**
- `CRISP_WEBSITE_ID`: Crisp website identifier
- **Why needed**: Provides in-app customer support chat so users can get help without leaving the app.
- **What the app does**:
  - Displays a chat widget in the app
  - Allows users to message support directly
  - Shows support availability status
  - Can send automated messages or FAQs
- **Where it's used**: `lib/core/chat/crisp_service.dart` - initialized in main.dart and accessible from profile/settings screens
- Get from: [Crisp Dashboard](https://app.crisp.chat/)

**OpenAI (AI-Powered Features)**
- `OPENAI_API_KEY`: OpenAI API key for food recognition and chatbot
- **Why needed**: Powers two main AI features - food recognition from photos and the chatbot assistant.
- **What the app does**:
  - **Food Scanner**: When users take a photo of food, OpenAI Vision API analyzes the image and identifies what food it is, then provides nutritional information and sugar content
  - **Chatbot**: Provides AI-powered support and guidance when users need help or have questions about sugar addiction
  - **Content Generation**: May be used for generating personalized content or responses
- **Where it's used**: 
  - Food scanning: `lib/features/app/presentation/screens/food_scan/food_scan_screen.dart`
  - Chatbot: `lib/features/app/presentation/screens/chatbot/chatbot_screen.dart`
- Get from: [OpenAI API Keys](https://platform.openai.com/api-keys)

**Firebase Configuration**
- `FIREBASE_PROJECT_ID`: Your Firebase project ID
- `FIREBASE_ANDROID_API_KEY`: Android app API key from Firebase
- `FIREBASE_ANDROID_APP_ID`: Android app ID from Firebase
- `FIREBASE_IOS_API_KEY`: iOS app API key from Firebase
- `FIREBASE_IOS_APP_ID`: iOS app ID from Firebase
- `FIREBASE_IOS_CLIENT_ID`: iOS OAuth client ID
- `FIREBASE_MESSAGING_SENDER_ID`: Firebase Cloud Messaging sender ID
- `FIREBASE_STORAGE_BUCKET`: Firebase Storage bucket name
- Get from: Firebase Console → Project Settings

**AppsFlyer (Marketing Attribution & Deep Linking)**
- `APPSFLYER_APP_ID`: AppsFlyer app ID
- `APPSFLYER_DEV_KEY`: AppsFlyer developer key
- `APPSFLYER_ONELINK_TEMPLATE`: AppsFlyer OneLink template ID
- **Why needed**: Tracks which marketing campaigns, ads, or referral sources brought users to the app. Essential for measuring marketing ROI.
- **What the app does**:
  - Tracks user acquisition sources (Facebook ads, Google ads, referrals, etc.)
  - Measures which campaigns convert best
  - Enables deep linking (users clicking ads go directly to specific screens)
  - Tracks user lifetime value by acquisition source
  - Provides attribution data for marketing optimization
- **Where it's used**: `lib/core/analytics/appsflyer_service.dart` - initialized at app startup
- Get from: [AppsFlyer Dashboard](https://hq1.appsflyer.com/)

**Groq (Alternative AI Provider)**
- `GROQ_API_KEY`: Groq API key
- **Why needed**: Alternative to OpenAI for AI features. Groq offers faster inference speeds and may be cheaper for certain use cases.
- **What the app does**: Can be used as a fallback or alternative to OpenAI for:
  - Food recognition (if OpenAI is unavailable or too slow)
  - Chatbot responses
  - Content generation
- **Where it's used**: May be used in food scanning or chatbot features as an alternative to OpenAI
- Get from: [Groq Console](https://console.groq.com/keys)

**Replicate (AI Model Hosting)**
- `REPLICATE_API_TOKEN`: Replicate API token
- **Why needed**: Replicate hosts specialized AI models that might be used for image processing, food analysis, or other AI tasks.
- **What the app does**: Can be used for advanced image processing or specialized AI tasks beyond what OpenAI/Groq provide.
- **Where it's used**: May be used for advanced food analysis or image processing features
- Get from: [Replicate Account](https://replicate.com/account/api-tokens)

**Edamam (Nutrition Database API)**
- `EDAMAM_API_KEY`: Edamam API key
- `EDAMAM_APP_ID`: Edamam application ID
- **Why needed**: Provides comprehensive nutrition database with detailed nutritional information for thousands of foods.
- **What the app does**:
  - When users scan food or search for foods, Edamam provides:
    - Calorie counts
    - Macronutrients (protein, carbs, fats)
    - Micronutrients (vitamins, minerals)
    - Sugar content
    - Allergen information
  - Used in the nutrition tracking features to give users accurate nutritional data
- **Where it's used**: `lib/features/nutrition/data/repositories/nutrition_repository.dart` - food database queries
- Get from: [Edamam Developer Portal](https://developer.edamam.com/)

**Spoonacular (Recipe API - Backup for Edamam)**
- `SPOONACULAR_API_KEY`: Spoonacular API key
- **Why needed**: Provides access to a large database of recipes, including sugar-free and healthy alternatives. **Serves as a backup/fallback for Edamam** - if Edamam API fails or is unavailable, the app automatically falls back to Spoonacular to ensure users can still search for recipes.
- **What the app does**:
  - **Primary use**: Fetches recipes for users looking for sugar-free alternatives when Edamam is unavailable
  - Provides recipe details (ingredients, instructions, nutrition info)
  - Filters recipes by dietary preferences (sugar-free, low-carb, etc.)
  - Used in the recipes feature to help users find healthy meal options
  - **Fallback mechanism**: If Edamam API call fails, the app automatically retries with Spoonacular to ensure recipe search always works
- **Where it's used**: `lib/features/recipes/data/repositories/recipe_repository.dart` - recipe searches and details (fallback when Edamam fails)
- Get from: [Spoonacular Food API](https://spoonacular.com/food-api)

**Mux (Video Hosting & Streaming)**
- `MUX_TOKEN_ID`: Mux token ID
- `MUX_SECRET_KEY`: Mux secret key
- **Why needed**: Mux hosts and streams the educational videos in the "Learn" section of the app.
- **What the app does**:
  - Stores educational videos about sugar addiction
  - Streams videos to users with adaptive bitrate (adjusts quality based on connection)
  - Provides video analytics (watch time, completion rates)
  - Generates video thumbnails
  - Handles video subtitles/captions
- **Where it's used**: `lib/features/learn/presentation/screens/` - video playback in learn section
- Get from: [Mux Dashboard](https://dashboard.mux.com/settings/access-tokens)

**SendGrid (Email Delivery Service)**
- `SENDGRID_API_KEY`: SendGrid API key
- **Why needed**: Sends transactional emails to users (welcome emails, password resets, important notifications).
- **What the app does**:
  - Sends welcome emails when users sign up
  - Sends password reset emails
  - Sends important notifications (subscription confirmations, account updates)
  - May send weekly progress reports or motivational emails
- **Where it's used**: Firebase Cloud Functions (`tools/firebase_cloud/functions/`) - server-side email sending
- Get from: [SendGrid API Keys](https://app.sendgrid.com/settings/api_keys)

**Stripe (Payment Processing)**
- `STRIPE_WEBHOOK_SECRET`: Stripe webhook signing secret
- `STRIPE_WEBHOOK_URL`: Stripe webhook endpoint URL (optional, defaults to Firebase function URL)
- **Why needed**: Stripe webhooks notify the app when payment events occur (subscription created, payment succeeded, etc.). The webhook secret is used to verify that webhook requests are actually from Stripe.
- **What the app does**:
  - Receives webhook events from Stripe about subscription status changes
  - Updates user subscription status in Firestore
  - Handles payment confirmations and failures
  - Processes subscription cancellations and renewals
- **Where it's used**: 
  - Firebase Cloud Functions (`tools/firebase_cloud/functions/stripeWebhook`) - webhook handler
  - Makefile `firebase-deploy` target - for deploying webhook configuration (requires `STRIPE_WEBHOOK_SECRET` environment variable)
- **⚠️ SENSITIVE**: The webhook secret must be kept secure. Never commit it to version control.
- Get from: [Stripe Dashboard](https://dashboard.stripe.com/webhooks) → Your webhook → Signing secret
- **Usage**: Set environment variable before deploying: `export STRIPE_WEBHOOK_SECRET=whsec_...` then run `make firebase-deploy`


## Config Files Generation

This section explains how to generate all required configuration files for the app.

### 1. Firebase Configuration Files

#### iOS: `ios/Runner/GoogleService-Info.plist`

**Why needed**: Required for Firebase iOS SDK to connect to your Firebase project. Contains API keys, project ID, and app configuration.

**How to generate**:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (or create a new one)
3. Click the iOS icon to add an iOS app
4. Enter your iOS bundle ID (e.g., `com.stoppr.app`)
5. Download the `GoogleService-Info.plist` file
6. Place it in `ios/Runner/GoogleService-Info.plist`
7. The file will be automatically included in your Xcode project

**What it contains**:
- `API_KEY`: Firebase API key for iOS
- `GCM_SENDER_ID`: Cloud Messaging sender ID
- `BUNDLE_ID`: Your app's bundle identifier
- `PROJECT_ID`: Firebase project ID
- `STORAGE_BUCKET`: Firebase Storage bucket
- `CLIENT_ID`: OAuth client ID for Google Sign-In

#### Android: `android/app/google-services.json`

**Why needed**: Required for Firebase Android SDK to connect to your Firebase project. Contains API keys, project ID, and app configuration.

**How to generate**:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Click the Android icon to add an Android app
4. Enter your Android package name (e.g., `com.stoppr.sugar.app`)
5. Enter your app's SHA-1 certificate fingerprint (for Google Sign-In)
   - Get SHA-1: `keytool -list -v -keystore android/app/release/stoppr-release-key.keystore`
6. Download the `google-services.json` file
7. Place it in `android/app/google-services.json`
8. The file will be automatically processed by the Google Services Gradle plugin

**What it contains**:
- `project_info`: Project number, ID, and storage bucket
- `client`: App configuration including API keys and OAuth clients
- `services`: Additional service configurations

#### Flutter: `lib/firebase_options.dart`

**Why needed**: FlutterFire requires platform-specific Firebase options. This file is generated by FlutterFire CLI and contains Firebase configuration for both iOS and Android.

**How to generate**:

1. Install FlutterFire CLI (if not already installed):
   ```bash
   dart pub global activate flutterfire_cli
   ```

2. Make sure you're logged into Firebase:
   ```bash
   firebase login
   ```

3. Run FlutterFire configuration:
   ```bash
   flutterfire configure
   ```

4. Select your Firebase project
5. Select platforms (iOS and Android)
6. The CLI will:
   - Download `GoogleService-Info.plist` for iOS
   - Download `google-services.json` for Android
   - Generate `lib/firebase_options.dart` with platform-specific options

**Note**: The generated `firebase_options.dart` uses environment variables from `.env` file via `EnvConfig` class. Make sure your `.env` file has the correct Firebase values.

#### Root: `firebase.json`

**Why needed**: Firebase CLI configuration file that defines project settings, deployment targets, and file paths for Firebase services (Firestore, Functions, Storage, Hosting, etc.). Contains project-specific IDs and configuration.

**How to generate**:

1. **Option 1: Copy from template** (recommended if using existing project):
   ```bash
   cp firebase.json.local firebase.json
   ```
   Then edit `firebase.json` to replace placeholders:
   - Replace `YOUR_PROJECT_ID` with your Firebase project ID
   - Replace `YOUR_IOS_APP_ID` with your iOS app ID from Firebase Console
   - Replace `YOUR_ANDROID_APP_ID` with your Android app ID from Firebase Console

2. **Option 2: Generate via Firebase CLI** (if starting fresh):
   ```bash
   firebase init
   ```
   Follow the prompts to configure:
   - Select your Firebase project
   - Choose services to configure (Firestore, Functions, Storage, Hosting, etc.)
   - Configure each service as needed

**What it contains**:
- `flutter.platforms`: iOS and Android app configuration with project IDs and app IDs
- `firestore`: Rules and indexes file paths
- `functions`: Cloud Functions source directory and runtime configuration
- `storage`: Storage rules file path
- `hosting`: Hosting configuration (if using Firebase Hosting)
- `extensions`: Firebase Extensions configuration

**⚠️ IMPORTANT**: This file contains project-specific configuration and is **not committed to git**. Always create it from `firebase.json.local` template or generate it via `firebase init`.

### 2. Firebase Services Configuration

**⚠️ IMPORTANT**: Before the app can function, you must enable the following Firebase services in your Firebase Console:

#### Required Firebase Services

1. **Firebase Authentication**
   - **Enable**: Email/Password, Google Sign-In, Apple Sign-In (for iOS)
   - **Location**: Firebase Console → Authentication → Sign-in method
   - **Why needed**: User authentication and account management
   - **Configuration**:
     - Enable "Email/Password" provider
     - Enable "Google" provider (requires OAuth client IDs from Google Cloud Console)
     - Enable "Apple" provider (requires Apple Developer account setup)
     - Configure authorized domains for OAuth redirects

2. **Cloud Firestore**
   - **Enable**: Create Firestore database
   - **Location**: Firebase Console → Firestore Database → Create database
   - **Why needed**: Stores user data, questionnaire answers, streaks, food logs, etc.
   - **Configuration**:
     - Choose "Start in production mode" (you'll configure rules below)
     - Select a region (choose closest to your users)
     - **⚠️ CRITICAL**: Configure security rules (see Firestore Rules section below)

3. **Firebase Cloud Messaging (FCM)**
   - **Enable**: Cloud Messaging API
   - **Location**: Firebase Console → Cloud Messaging
   - **Why needed**: Push notifications for accountability partners and server-sent notifications
   - **Configuration**:
     - FCM is automatically enabled when you create a Firebase project
     - No additional setup needed, but ensure Cloud Messaging API is enabled in Google Cloud Console
     - **iOS**: Requires APNs certificate upload (see iOS setup below)
     - **Android**: Works automatically with `google-services.json`

4. **Firebase Storage**
   - **Enable**: Cloud Storage
   - **Location**: Firebase Console → Storage → Get started
   - **Why needed**: Stores user-uploaded images (food photos, profile pictures, etc.)
   - **Configuration**:
     - Choose "Start in production mode"
     - Select same region as Firestore
     - **⚠️ CRITICAL**: Configure security rules (see Storage Rules section below)

5. **Firebase Analytics**
   - **Enable**: Google Analytics for Firebase
   - **Location**: Firebase Console → Analytics → Get started
   - **Why needed**: User behavior tracking and app performance metrics
   - **Configuration**:
     - Link to Google Analytics property (or create new one)
     - Enable data collection for iOS and Android

6. **Firebase Cloud Functions** (Optional but Recommended)
   - **Enable**: Cloud Functions
   - **Location**: Firebase Console → Functions
   - **Why needed**: Server-side logic (Stripe webhooks, email sending, etc.)
   - **Configuration**:
     - Requires Firebase CLI: `firebase init functions`
     - Select Node.js runtime (18.x recommended)
     - Deploy functions from `tools/firebase_cloud/functions/`

#### iOS-Specific Firebase Setup

**APNs Certificate for FCM**:
1. Go to Firebase Console → Project Settings → Cloud Messaging
2. Under "Apple app configuration", upload your APNs certificate:
   - **Option 1**: Upload APNs Authentication Key (.p8 file)
     - Generate in Apple Developer Portal → Certificates, Identifiers & Profiles → Keys
     - Download the .p8 file and upload to Firebase
   - **Option 2**: Upload APNs Certificate (.p12 file)
     - Export from Keychain Access
     - Upload to Firebase
3. This enables push notifications on iOS devices

**iOS Capabilities**:
- Ensure "Push Notifications" capability is enabled in Xcode
- Ensure "Background Modes" → "Remote notifications" is enabled
- Verify `ios/Runner/Runner.entitlements` includes `aps-environment`

#### Android-Specific Firebase Setup

**FCM Auto-Initialization**:
- FCM is automatically initialized when `google-services.json` is properly configured
- No additional setup needed for Android 12 and below
- Android 13+ requires runtime permission request (handled by app)

### 3. Firestore Security Rules

**⚠️ CRITICAL**: You MUST configure Firestore security rules before deploying to production. The app will not work correctly without proper rules.

**Create `firestore.rules` file** in your project root:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function to check if user owns the document
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    // Users collection
    match /users/{userId} {
      // Users can read their own document
      allow read: if isOwner(userId);
      
      // Users can create/update their own document
      allow create: if isOwner(userId);
      allow update: if isOwner(userId) && 
        // Prevent users from modifying critical fields
        !request.resource.data.diff(resource.data).affectedKeys().hasAny(['createdAt', 'isDeleted']);
      
      // Users can write their own FCM token
      allow write: if isOwner(userId) && 
        request.resource.data.keys().hasOnly(['fcmToken', 'fcmTokenUpdatedAt']);
    }
    
    // User subcollections
    match /users/{userId}/favorite_recipes/{recipeId} {
      allow read, write: if isOwner(userId);
    }
    
    // Food logs collection
    match /food_logs/{logId} {
      allow read: if isAuthenticated() && resource.data.userId == request.auth.uid;
      allow create: if isAuthenticated() && request.resource.data.userId == request.auth.uid;
      allow update, delete: if isAuthenticated() && resource.data.userId == request.auth.uid;
    }
    
    // Questionnaire answers (stored during onboarding)
    match /questionnaire_answers/{answerId} {
      allow read, write: if isAuthenticated() && 
        (resource == null || resource.data.userId == request.auth.uid) &&
        (request.resource == null || request.resource.data.userId == request.auth.uid);
    }
    
    // Redownload feedback collection
    match /redownload_feedback/{feedbackId} {
      allow create: if isAuthenticated();
      allow read: if false; // Only admins can read (use Firebase Admin SDK)
    }
    
    // Transaction failures (for debugging)
    match /transactions_fail/{transactionId} {
      allow create: if isAuthenticated();
      allow read: if false; // Only admins can read
    }
    
    // Security alerts (for fraud detection)
    match /security_alerts/{alertId} {
      allow create: if isAuthenticated();
      allow read: if false; // Only admins can read
    }
    
    // Deny all other collections by default
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

**Deploy Firestore Rules**:
```bash
firebase deploy --only firestore:rules
```

**⚠️ SECURITY NOTES**:
- These rules allow users to read/write their own data only
- Critical fields like `createdAt` and `isDeleted` cannot be modified by users
- Admin-only collections (like `security_alerts`) require Firebase Admin SDK to read
- Test your rules using Firebase Console → Firestore → Rules → Rules Playground

### 4. Firebase Storage Security Rules

**⚠️ CRITICAL**: Configure Storage rules to prevent unauthorized access to user uploads.

**Create `storage.rules` file** in your project root:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    
    // User profile pictures
    match /profile_pictures/{userId}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId &&
        request.resource.size < 5 * 1024 * 1024 && // Max 5MB
        request.resource.contentType.matches('image/.*');
    }
    
    // Food scan images
    match /food_scans/{userId}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId &&
        request.resource.size < 10 * 1024 * 1024 && // Max 10MB
        request.resource.contentType.matches('image/.*');
    }
    
    // Meal photos
    match /meal_photos/{userId}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId &&
        request.resource.size < 10 * 1024 * 1024 && // Max 10MB
        request.resource.contentType.matches('image/.*');
    }
    
    // Deny all other paths
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

**Deploy Storage Rules**:
```bash
firebase deploy --only storage:rules
```

**⚠️ SECURITY NOTES**:
- Users can only upload to their own user ID folder
- File size limits prevent abuse (5MB for profile pics, 10MB for food photos)
- Only image files are allowed (content type validation)
- All uploads require authentication

### 5. Firebase Service Account JSON

**Why needed**: Required for server-side Firebase operations, such as:
- Firebase Cloud Functions authentication
- Admin SDK operations (user management, Firestore admin operations)
- Server-side scripts that need elevated permissions

**File locations** (you'll need one for each tool that requires it):
- `tools/firebase_cloud/functions/stoppr-f2d4a-firebase-adminsdk-*.json`
- `tools/user_management/firestore_queries/stoppr-f2d4a-firebase-adminsdk-*.json`
- `tools/learn_articles/stoppr-f2d4a-firebase-adminsdk-*.json`

**How to generate**:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to Project Settings (gear icon)
4. Navigate to "Service accounts" tab
5. Click "Generate new private key"
6. A JSON file will be downloaded
7. Rename it to match the expected filename pattern: `stoppr-<project-id>-firebase-adminsdk-<random>.json`
8. Place it in the appropriate `tools/` directory:
   - For Firebase Functions: `tools/firebase_cloud/functions/`
   - For user management scripts: `tools/user_management/firestore_queries/`
   - For article upload scripts: `tools/learn_articles/`

**Security Note**: 
- Never commit this file to version control
- Add to `.gitignore`: `**/stoppr-*-firebase-adminsdk-*.json`
- This file contains private keys with admin access to your Firebase project

**Usage in code**:
```javascript
// Example: Firebase Functions
const admin = require('firebase-admin');
const serviceAccount = require('./stoppr-f2d4a-firebase-adminsdk-*.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});
```

### 3. Apple Store Connect Auth Key (.p8)

**Why needed**: Required for automated App Store Connect operations, such as:
- Fetching app analytics
- Managing app metadata
- Automated build uploads (via CI/CD)

**File location**: `tools/apple-store-connect/AuthKey_<KEY_ID>.p8`

**How to generate**:

1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Navigate to Users and Access → Keys
3. Click the "+" button to create a new key
4. Enter a name for the key (e.g., "Stoppr CI/CD Key")
5. Select "App Manager" or "Admin" role
6. Click "Generate"
7. Download the `.p8` file immediately (you can only download it once)
8. Note the Key ID (shown in the key details)
9. Rename the file to `AuthKey_<KEY_ID>.p8` (replace `<KEY_ID>` with the actual key ID)
10. Place it in `tools/apple-store-connect/`

**Security Note**:
- Never commit this file to version control
- Add to `.gitignore`: `**/*.p8`
- Store the Key ID and Issuer ID securely (you'll need them for API calls)

**Usage**:
```javascript
// Example: Using the key with App Store Connect API
const { AppStoreConnectApi } = require('@apple/app-store-connect-api');
// Key ID and Issuer ID are used with the .p8 file for authentication
```

### 4. Android Signing Configuration

#### `android/key.properties`

**Why needed**: Contains Android app signing credentials for release builds. Required to sign your app for Google Play Store distribution.

**How to create**:

1. **Generate a keystore** (if you don't have one):
   ```bash
   keytool -genkey -v -keystore android/app/release/stoppr-release-key.keystore \
     -alias stoppr -keyalg RSA -keysize 2048 -validity 10000
   ```
   - Enter a password (remember this!)
   - Fill in the certificate information
   - The keystore file will be created at `android/app/release/stoppr-release-key.keystore`

2. **Create `android/key.properties`**:
   ```properties
   storePassword=YOUR_KEYSTORE_PASSWORD
   keyPassword=YOUR_KEY_PASSWORD
   keyAlias=stoppr
   storeFile=release/stoppr-release-key.keystore
   ```

3. **Replace placeholders**:
   - `YOUR_KEYSTORE_PASSWORD`: The password you used when creating the keystore
   - `YOUR_KEY_PASSWORD`: Usually the same as keystore password (unless you set a different key password)
   - `keyAlias`: The alias you used when creating the keystore (default: `stoppr`)
   - `storeFile`: Path relative to `android/app/` directory

**Security Note**:
- Never commit `key.properties` to version control
- Add to `.gitignore`: `android/key.properties`
- Keep your keystore file secure and backed up
- If you lose the keystore, you cannot update your app on Google Play

**Usage**: The `android/app/build.gradle.kts` file automatically reads this file for signing configuration.

### 5. iOS Export Options

#### `ios/exportOptions.plist`

**Why needed**: Required for exporting iOS builds for App Store distribution. Contains signing certificates, provisioning profiles, and export settings.

**How to create/configure**:

1. **Basic template** (already exists in the repo):
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>destination</key>
       <string>export</string>
       <key>method</key>
       <string>app-store</string>
       <key>provisioningProfiles</key>
       <dict>
           <key>com.stoppr.app</key>
           <string>YOUR_PROVISIONING_PROFILE_NAME</string>
           <key>com.stoppr.app.StreakWidget</key>
           <string>YOUR_WIDGET_PROVISIONING_PROFILE_NAME</string>
       </dict>
       <key>signingCertificate</key>
       <string>Apple Distribution</string>
       <key>signingStyle</key>
       <string>manual</string>
       <key>teamID</key>
       <string>YOUR_TEAM_ID</string>
   </dict>
   </plist>
   ```

2. **Get your Team ID**:
   - Go to [Apple Developer](https://developer.apple.com/account/)
   - Your Team ID is shown in the top right corner

3. **Get Provisioning Profile names**:
   - Go to [Apple Developer Portal](https://developer.apple.com/account/resources/profiles/list)
   - Find your App Store Distribution profiles
   - Use the exact name shown in the portal

4. **Update the file**:
   - Replace `YOUR_TEAM_ID` with your actual Team ID
   - Replace `YOUR_PROVISIONING_PROFILE_NAME` with your main app provisioning profile name
   - Replace `YOUR_WIDGET_PROVISIONING_PROFILE_NAME` with your widget extension provisioning profile name

**Usage**: This file is used when building for App Store:
```bash
flutter build ipa --export-options-plist=ios/exportOptions.plist
```

## Development Guide

### Code Generation

The project uses code generation for:
- **Freezed**: Immutable data classes and union types
- **json_serializable**: JSON serialization/deserialization

**Generate code**:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

**Watch for changes** (auto-regenerate on file save):
```bash
flutter pub run build_runner watch --delete-conflicting-outputs
```

### Localization

The app supports multiple languages. Localization files are in `assets/l10n/`:

- `en.json` - English
- `fr.json` - French
- `es.json` - Spanish
- `de.json` - German
- `it.json` - Italian
- `ru.json` - Russian
- `cs.json` - Czech
- `sk.json` - Slovak
- `zh.json` - Chinese
- `pl.json` - Polish

**Adding a new language**:
1. Create a new JSON file in `assets/l10n/`
2. Copy structure from `en.json`
3. Translate all string values
4. Add language to `pubspec.yaml` if needed

**Using localized strings**:
```dart
import 'package:stoppr/core/localization/app_localizations.dart';

Text(AppLocalizations.of(context)!.yourKey)
```

**Localization Smart Features** (Implementation Details):

**Hot Reload Support** (Development Only):
- The `AppLocalizations` class includes debug-only methods for hot reloading translations:
  - `evictFromCache(Locale locale)`: Clears cache for a specific language
  - `evictAllFromCache()`: Clears all language caches
  - `forceReload()`: Forces reload of current language strings
- This allows developers to edit JSON files and see changes without full app restart
- Only works in debug mode (`kDebugMode`)

**Text Sanitization**:
- All localized strings are sanitized via `TextSanitizer.sanitizeForDisplay()` before display
- Handles malformed UTF-16 characters and encoding issues
- Prevents crashes from corrupted JSON files

**Fallback Strategy**:
- If a translation key is missing, returns the key itself (sanitized)
- If a language file fails to load, falls back to English
- If English fails, returns empty map (prevents crashes)

**Cache Management**:
- Localization files are cached in production for performance
- Cache is disabled in debug mode for easier development
- Cache is automatically evicted when language changes

### Testing

Run tests:
```bash
flutter test
```

Run tests with coverage:
```bash
flutter test --coverage
```

### Common Commands (Makefile)

The project includes a `Makefile` with helpful commands:

**iOS Development**:
```bash
make run                    # Run on default simulator
make flutter-run-iphone16   # Run on iPhone 16 simulator
make pod-install            # Install iOS dependencies
make reset-ios              # Complete iOS reset (clean everything)
```

**Android Development**:
```bash
make flutter-run-android-emulator-adb  # Run on Android emulator
make build-android-aap                  # Build Android App Bundle
make reset-android                      # Complete Android reset
```

**General**:
```bash
make format                # Format Dart code
make analyze               # Analyze code for issues
make delete-conflicting-outputs  # Regenerate code files
```

**Note**: Some Makefile commands contain personal paths (like DerivedData paths). Update these for your system or use Flutter commands directly.

### Project-Specific Conventions

1. **File Naming**: Use snake_case for Dart files
2. **Widget Structure**: Export widget first, then subwidgets, helpers, static content, types
3. **State Management**: Use Cubit for simple state, Bloc for complex event-driven state
4. **Error Handling**: Display errors using `SelectableText.rich` (not SnackBars)
5. **Imports**: Always use full package paths (e.g., `package:stoppr/features/...`)
6. **Debugging**: Use `debugPrint()` instead of `print()` or `log()`
7. **Line Length**: Keep lines under 80 characters
8. **Trailing Commas**: Always use trailing commas in multi-line function calls

## Building & Running

### ⚠️ CRITICAL: Use Make Commands, NOT Xcode Directly

**IMPORTANT**: This project **MUST** be built and run using the provided Make commands. **DO NOT** attempt to build or run the app directly from Xcode, as it will not work correctly. The Makefile contains essential setup steps, dependency management, and build configurations that are required for the app to function properly.

### Why Make Commands Are Required

The Makefile (`Makefile`) handles:
- Proper Flutter plugin setup and linking
- CocoaPods dependency installation and configuration
- Xcode workspace configuration
- Derived data management
- Simulator booting and configuration
- Flutter hot reload setup
- Code generation (Freezed, JSON serialization)
- Proper build paths and binary locations

Building directly from Xcode bypasses these critical setup steps and will result in build failures, missing dependencies, or runtime errors.

### iOS Development Workflow

#### 1. First-Time Setup (Required Once)

Before running the app for the first time, or if you encounter build issues, run the complete reset:

```bash
make reset-ios
```

**What `reset-ios` does**:
- Closes Xcode if running
- Cleans Flutter build cache
- Removes iOS build artifacts (Pods, DerivedData, etc.)
- Cleans CocoaPods cache
- Reinstalls all dependencies (Flutter packages and CocoaPods)
- Regenerates all code (Freezed, JSON serialization)
- Resets iOS simulators
- Opens Xcode workspace automatically

**Note**: This command takes 5-10 minutes to complete. Only run it when:
- Setting up the project for the first time
- After pulling major changes
- When experiencing build errors that normal cleaning doesn't fix

#### 2. Running the App on iOS Simulator

After running `reset-ios` (or if you've already set up the project), use one of these commands to run the app:

**iPhone XS (Recommended for testing)**:
```bash
make flutter-run-iphonex
```

**Other available simulators**:
```bash
make flutter-run-iphone15      # iPhone 15
make flutter-run-iphone15-pro  # iPhone 15 Pro
make flutter-run-iphone16      # iPhone 16
make flutter-run-ipad-pro-11   # iPad Pro 11-inch
make flutter-run-ipad-pro-13   # iPad Pro 13-inch
make flutter-run-ipad-air-11   # iPad Air 11-inch
```

**What these commands do**:
1. Boot the specified iOS simulator
2. Open Simulator app
3. Build the iOS app with Xcode
4. Locate the built binary
5. Run Flutter with hot reload support
6. Attach Flutter debugger for hot reload

**Hot Reload**: Once the app is running, you can use Flutter's hot reload:
- Press `r` in the terminal to hot reload
- Press `R` to hot restart
- Press `q` to quit

#### 3. Quick Reset (If Needed)

If you only need to clean Flutter and regenerate code (faster than full reset):

```bash
make reset-quick
```

**What `reset-quick` does**:
- Cleans Flutter build cache
- Reinstalls Flutter dependencies
- Regenerates code (Freezed, JSON serialization)
- Does NOT clean iOS/Pods (faster)

Use this when:
- Code generation files are out of sync
- You've modified Freezed models or JSON serialization
- You don't need a full iOS reset

#### 4. Listing Available Simulators

To see all available iOS simulators:

```bash
make list-sims
```

#### 5. Opening Simulator Manually

To open the iOS Simulator without running the app:

```bash
make open-sim
```

### Common Build Issues and Solutions

#### Issue: "No such module" or "Missing Pods"

**Solution**: Run `make reset-ios` to reinstall all CocoaPods dependencies.

#### Issue: "Flutter plugin not found"

**Solution**: Run `make reset-ios` to properly link Flutter plugins.

#### Issue: Code generation errors (Freezed/JSON)

**Solution**: Run `make reset-quick` to regenerate all code files.

#### Issue: Simulator won't boot

**Solution**: 
```bash
xcrun simctl shutdown all
xcrun simctl erase all
make reset-ios
```

#### Issue: Xcode build fails

**Solution**: 
1. Close Xcode completely
2. Run `make reset-ios`
3. Wait for it to complete and open Xcode automatically
4. Use Make commands to run, not Xcode's Run button

### Android Development

For Android development, use these commands:

```bash
make flutter-run-android-xs          # Run on Pixel 4 emulator
make flutter-run-android-pixel6pro   # Run on Pixel 6 Pro emulator
make list-android-emulators          # List available Android emulators
make reset-android                   # Reset Android build environment
```

### Building for Release

#### iOS Release Build

```bash
make build-release
```

This builds the iOS app in release mode. For TestFlight distribution:

```bash
make build-testflight
```

#### Android Release Build

```bash
make build-android-aap
```

This builds an Android App Bundle (AAB) for Google Play Store.

### Available Make Commands

Run `make help` to see all available commands:

```bash
make help
```

**Common commands**:
- `make reset-ios` - Complete iOS reset (use first time or when having issues)
- `make reset-quick` - Quick Flutter reset (regenerates code)
- `make flutter-run-iphonex` - Run on iPhone XS simulator
- `make flutter-run-iphone15` - Run on iPhone 15 simulator
- `make flutter-run-iphone16` - Run on iPhone 16 simulator
- `make list-sims` - List available iOS simulators
- `make open-sim` - Open iOS Simulator
- `make build-release` - Build iOS release
- `make build-testflight` - Build for TestFlight
- `make pod-install` - Install CocoaPods dependencies only
- `make clean-xcode` - Clean Xcode derived data
- `make format` - Format Dart code
- `make analyze` - Analyze Dart code

### Development Tips

1. **Always use Make commands**: Never build/run directly from Xcode
2. **Run `reset-ios` first**: On first setup or when encountering build issues
3. **Use hot reload**: Once app is running, use `r` for hot reload instead of rebuilding
4. **Check Flutter doctor**: Run `flutter doctor -v` if you encounter environment issues
5. **Keep dependencies updated**: Run `flutter pub get` after pulling changes

### Troubleshooting

#### Flutter Analyze Errors

If you encounter errors when running `flutter analyze`, here are common issues and solutions:

**Issue: "The constant name 'X' isn't a lowerCamelCase identifier"**

**Solution**: This is a lint warning, not an error. The app will still compile and run. To fix:
- Rename constants to use `lowerCamelCase` (e.g., `DRY_RUN` → `dryRun`)
- Or add an ignore comment: `// ignore: constant_identifier_names`

**Issue: "Don't invoke 'print' in production code"**

**Solution**: Replace `print()` with `debugPrint()`:
```dart
// Bad
print('Debug message');

// Good
debugPrint('Debug message');
```

**Issue: "The value of the local variable 'X' isn't used"**

**Solution**: 
- Remove the unused variable if it's not needed
- Or prefix with underscore if intentionally unused: `_unusedVariable`
- Or add ignore comment: `// ignore: unused_local_variable`

**Issue: "Prefer const constructors"**

**Solution**: Add `const` keyword to widget constructors:
```dart
// Bad
Widget build(BuildContext context) {
  return Container(color: Colors.red);
}

// Good
Widget build(BuildContext context) {
  return const Container(color: Colors.red);
}
```

**Issue: "Avoid using 'as' for type casting"**

**Solution**: Use null-safe casting or pattern matching:
```dart
// Bad
final value = someValue as String;

// Good
final value = someValue is String ? someValue : '';
// Or
final value = someValue as String? ?? '';
```

**Issue: "Prefer single quotes for string literals"**

**Solution**: Use single quotes instead of double quotes:
```dart
// Bad
final text = "Hello";

// Good
final text = 'Hello';
```

**Issue: "Lines longer than 80 characters"**

**Solution**: Break long lines:
```dart
// Bad
final longVariableName = SomeVeryLongClassName(parameter1: value1, parameter2: value2, parameter3: value3);

// Good
final longVariableName = SomeVeryLongClassName(
  parameter1: value1,
  parameter2: value2,
  parameter3: value3,
);
```

**Issue: "Missing required parameter"**

**Solution**: Add the required parameter or make it optional:
```dart
// Bad
SomeWidget(); // Missing required 'title' parameter

// Good
SomeWidget(title: 'My Title');
```

**Issue: "Unused import"**

**Solution**: Remove unused imports or add ignore comment:
```dart
// Remove the import
// import 'package:unused/package.dart';

// Or ignore
// ignore: unused_import
import 'package:unused/package.dart';
```

**Running Flutter Analyze**:
```bash
# Run analyze
flutter analyze

# Run analyze with verbose output
flutter analyze -v

# Run analyze on specific file
flutter analyze lib/path/to/file.dart

# Fix auto-fixable issues
dart fix --apply
```

**Note**: Many `flutter analyze` warnings are style suggestions and won't prevent the app from running. Focus on errors (not warnings) if you need the app to compile.

#### General Troubleshooting

If you encounter issues not covered above:

1. **Check Flutter version**: Ensure you have Flutter 3.7.0+
   ```bash
   flutter --version
   ```

2. **Check Xcode version**: Ensure Xcode 14.0+ is installed
   ```bash
   xcodebuild -version
   ```

3. **Check CocoaPods**: Ensure CocoaPods is installed
   ```bash
   pod --version
   ```

4. **Check iOS Simulator**: Verify simulators are installed
   ```bash
   xcrun simctl list devices
   ```
   If no simulators appear, install them via Xcode → Preferences → Components

5. **Check Android Emulator** (if testing Android): Verify emulator is set up
   ```bash
   $ANDROID_SDK_ROOT/emulator/emulator -list-avds
   ```
   If no emulators appear, create one via Android Studio → Tools → Device Manager

6. **Clean everything**: Run `make reset-ios` to start fresh

7. **Check environment variables**: Ensure `.env` file is properly configured

8. **Check Firebase config**: Ensure `GoogleService-Info.plist` and `google-services.json` are present

9. **Check Team ID**: Ensure Team ID is set in Xcode project settings (step 5i)

10. **Check StoreKit config**: If testing purchases, ensure `Products.storekit` is configured in Xcode scheme (Product → Scheme → Edit Scheme → Run → Options → StoreKit Configuration)

## Contributing

When contributing to this project:

1. Follow the coding conventions outlined in the Development Guide
2. Ensure all code generation is up to date
3. Test on both iOS and Android
4. Update localization files if adding user-facing strings
5. Document any new environment variables or configuration requirements
6. Keep sensitive files out of version control (check `.gitignore`)

## Support

For issues, questions, or contributions, please [create an issue](link-to-issues) or contact the maintainers.
