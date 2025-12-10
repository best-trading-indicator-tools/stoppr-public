class QuestionModel {
  final int id;
  final String questionText;
  final String englishQuestion;
  final List<String> options;
  final List<String> optionsEnglish;
  final Map<String, String> optionHelpTexts;
  final bool isMultiSelect;

  const QuestionModel({
    required this.id,
    required this.questionText,
    required this.englishQuestion,
    required this.options,
    required this.optionsEnglish,
    this.optionHelpTexts = const {},
    this.isMultiSelect = false,
  });
}

// Define all questionnaire questions
class QuestionnaireData {
  static const List<QuestionModel> questions = [
    // Question 1 - Emotional/Frustration Focus
    QuestionModel(
      id: 1,
      questionText: 'q1_text',
      englishQuestion: 'What frustrates you most about your relationship with sugar?',
      options: [
        'q1_option_hardToResist',
        'q1_option_goToComfort',
        'q1_option_keepTellingCutBack',
      ],
      optionsEnglish: [
        'I know I should eat less but it\'s hard to resist',
        'Sugar is my go-to for comfort or energy',
        'I keep telling myself I\'ll cut back, but never do',
      ],
      optionHelpTexts: {
        'q1_option_hardToResist': 'q1_help_hardToResist',
        'q1_option_goToComfort': 'q1_help_goToComfort',
        'q1_option_keepTellingCutBack': 'q1_help_keepTellingCutBack',
      },
      isMultiSelect: true,
    ),
    
    // Question 2 - Post-Consumption Focus
    QuestionModel(
      id: 2,
      questionText: 'q2_text',
      englishQuestion: 'How do you typically feel after eating sugar?',
      options: [
        'q2_option_regretful',
        'q2_option_crashSlugglish',
        'q2_option_moreCravings',
      ],
      optionsEnglish: [
        'I feel regretful and wish I hadn\'t eaten it',
        'I feel fine at first, but then crash and feel sluggish',
        'It triggers more cravings and I want even more',
      ],
      optionHelpTexts: {
        'q2_option_regretful': 'q2_help_regretful',
        'q2_option_crashSlugglish': 'q2_help_crashSlugglish',
        'q2_option_moreCravings': 'q2_help_moreCravings',
      },
    ),
    
    // Question 3 - Personal Impact
    QuestionModel(
      id: 3,
      questionText: 'q3_text',
      englishQuestion: 'Which area of your life has been most affected by your sugar habits?',
      options: [
        'q3_option_confidence',
        'q3_option_energyMood',
        'q3_option_healthAppearance',
        'q3_option_relationships',
      ],
      optionsEnglish: [
        'My confidence and self-image',
        'My energy levels and mood',
        'My physical health and appearance',
        'My relationships with food and eating',
      ],
      optionHelpTexts: {
        'q3_option_confidence': 'q3_help_confidence',
        'q3_option_energyMood': 'q3_help_energyMood',
        'q3_option_healthAppearance': 'q3_help_healthAppearance',
        'q3_option_relationships': 'q3_help_relationships',
      },
      isMultiSelect: true,
    ),
    
    // Question 4 - Emotional Triggers
    QuestionModel(
      id: 4,
      questionText: 'q4_text',
      englishQuestion: 'When do you most struggle with sugar cravings?',
      options: [
        'q4_option_stressed',
        'q4_option_sadLonely',
        'q4_option_lateNight',
        'q4_option_boredProcrastinating',
      ],
      optionsEnglish: [
        'When I\'m stressed or overwhelmed',
        'When I\'m feeling sad or lonely',
        'Late at night',
        'When I\'m bored or procrastinating',
      ],
      optionHelpTexts: {
        'q4_option_stressed': 'q4_help_stressed',
        'q4_option_sadLonely': 'q4_help_sadLonely',
        'q4_option_lateNight': 'q4_help_lateNight',
        'q4_option_boredProcrastinating': 'q4_help_boredProcrastinating',
      },
      isMultiSelect: true,
    ),
    
    // Question 6 (after consumption summary) - Consequences/Regret
    QuestionModel(
      id: 6,
      questionText: 'q6_text',
      englishQuestion: 'What\'s the biggest consequence you\'ve experienced from sugar consumption?',
      options: [
        'q6_option_disappointed',
        'q6_option_physicalSymptoms',
        'q6_option_avoidingSocial',
        'q6_option_notReachingPotential',
      ],
      optionsEnglish: [
        'Feeling disappointed in myself repeatedly',
        'Physical symptoms that interfere with my day',
        'Avoiding social situations because of my eating habits',
        'Feeling like I\'m not living up to my potential',
      ],
      optionHelpTexts: {
        'q6_option_disappointed': 'q6_help_disappointed',
        'q6_option_physicalSymptoms': 'q6_help_physicalSymptoms',
        'q6_option_avoidingSocial': 'q6_help_avoidingSocial',
        'q6_option_notReachingPotential': 'q6_help_notReachingPotential',
      },
      isMultiSelect: true,
    ),
    
    // Question 7 - Aspirational/Vision
    QuestionModel(
      id: 7,
      questionText: 'q7_text',
      englishQuestion: 'How would you feel if you had complete control over sugar cravings?',
      options: [
        'q7_option_proudConfident',
        'q7_option_freeLiberated',
        'q7_option_excitedGoals',
        'q7_option_calmPeaceful',
      ],
      optionsEnglish: [
        'Proud and confident in my self-discipline',
        'Free and liberated from constant mental battles',
        'Excited about reaching my health goals',
        'Calm and at peace with my food choices',
      ],
      optionHelpTexts: {
        'q7_option_proudConfident': 'q7_help_proudConfident',
        'q7_option_freeLiberated': 'q7_help_freeLiberated',
        'q7_option_excitedGoals': 'q7_help_excitedGoals',
        'q7_option_calmPeaceful': 'q7_help_calmPeaceful',
      },
      isMultiSelect: true,
    ),
    
    // Question 8 - Personal Motivation (Multi-select)
    QuestionModel(
      id: 8,
      questionText: 'q8_text',
      englishQuestion: 'What would achieving your sugar goals mean to you personally?',
      options: [
        'q8_option_provingCommitment',
        'q8_option_settingExample',
        'q8_option_comfortableInSkin',
        'q8_option_energyForDreams',
      ],
      optionsEnglish: [
        'Proving to myself that I can stick to my commitments',
        'Setting a good example for my family/loved ones',
        'Finally feeling comfortable in my own skin',
        'Having the energy to pursue my dreams',
      ],
      optionHelpTexts: {
        'q8_option_provingCommitment': 'q8_help_provingCommitment',
        'q8_option_settingExample': 'q8_help_settingExample',
        'q8_option_comfortableInSkin': 'q8_help_comfortableInSkin',
        'q8_option_energyForDreams': 'q8_help_energyForDreams',
      },
      isMultiSelect: true,
    ),
    
    // Question 9 - Social Pressure
    QuestionModel(
      id: 9,
      questionText: 'q9_text',
      englishQuestion: 'How do you typically handle social situations with sugary foods?',
      options: [
        'q9_option_giveInDifficult',
        'q9_option_anxiousUncomfortable',
        'q9_option_stickGoalsLeftOut',
      ],
      optionsEnglish: [
        'I give in to avoid making things awkward',
        'I feel anxious and uncomfortable the whole time',
        'I stick to my goals but feel left out',
      ],
      optionHelpTexts: {
        'q9_option_giveInDifficult': 'q9_help_giveInDifficult',
        'q9_option_anxiousUncomfortable': 'q9_help_anxiousUncomfortable',
        'q9_option_stickGoalsLeftOut': 'q9_help_stickGoalsLeftOut',
      },
    ),
    
    // Question 10 - Self-Perception
    QuestionModel(
      id: 10,
      questionText: 'q10_text',
      englishQuestion: 'How do you currently see yourself in relation to sugar?',
      options: [
        'q10_option_lacksWillpower',
        'q10_option_tryingStruggling',
        'q10_option_journeyImprovement',
        'q10_option_needsToolsSupport',
      ],
      optionsEnglish: [
        'As someone who lacks willpower',
        'As someone who\'s trying but struggling',
        'As someone who\'s on a journey of improvement',
        'On the right track, just need extra tools and support',
      ],
      optionHelpTexts: {
        'q10_option_lacksWillpower': 'q10_help_lacksWillpower',
        'q10_option_tryingStruggling': 'q10_help_tryingStruggling',
        'q10_option_journeyImprovement': 'q10_help_journeyImprovement',
        'q10_option_needsToolsSupport': 'q10_help_needsToolsSupport',
      },
    ),
    
    // Question 11 - Support Needs (Multi-select)
    QuestionModel(
      id: 11,
      questionText: 'q11_text',
      englishQuestion: 'What kind of support would make the biggest difference for you?',
      options: [
        'q11_option_understandingWhy',
        'q11_option_momentTools',
        'q11_option_connectingOthers',
        'q11_option_trackingProgress',
      ],
      optionsEnglish: [
        'Understanding why I crave sugar in the first place',
        'Having tools to use in the moment of craving',
        'Connecting with others who understand my struggle',
        'Tracking my progress to stay motivated',
      ],
      optionHelpTexts: {
        'q11_option_understandingWhy': 'q11_help_understandingWhy',
        'q11_option_momentTools': 'q11_help_momentTools',
        'q11_option_connectingOthers': 'q11_help_connectingOthers',
        'q11_option_trackingProgress': 'q11_help_trackingProgress',
      },
      isMultiSelect: true,
    ),
    
    // Question 12 - How did you hear about Stoppr (KEEP EXISTING)
    QuestionModel(
      id: 12,
      questionText: 'q12_text',
      englishQuestion: 'How did you know about Stoppr?',
      options: [
        'q12_option_tiktok',
        'q12_option_instagram',
        'q12_option_google',
        'q12_option_reddit',
        'q12_option_youtube',
        'q12_option_friendFamily',
        'q12_option_other',
      ],
      optionsEnglish: [
        'TikTok',
        'Instagram',
        'Google',
        'Reddit',
        'Youtube',
        'Friend or Family',
        'Other',
      ],
      optionHelpTexts: {
        'q12_option_tiktok': 'q12_help_tiktok',
        'q12_option_instagram': 'q12_help_instagram',
        'q12_option_google': 'q12_help_google',
        'q12_option_reddit': 'q12_help_reddit',
        'q12_option_youtube': 'q12_help_youtube',
        'q12_option_friendFamily': 'q12_help_friendFamily',
        'q12_option_other': 'q12_help_other',
      },
    ),
    
    // Question 13 - Gender (KEEP EXISTING)
    QuestionModel(
      id: 13,
      questionText: 'q13_text',
      englishQuestion: 'What is your gender?',
      options: [
        'q13_option_male',
        'q13_option_female',
        'q13_option_other',
      ],
      optionsEnglish: [
        'Male',
        'Female',
        'Other',
      ],
      optionHelpTexts: {
        'q13_option_male': 'q13_help_male',
        'q13_option_female': 'q13_help_female',
        'q13_option_other': 'q13_help_other',
      },
    ),
  ];
} 