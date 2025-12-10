import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stoppr/features/onboarding/domain/models/question_model.dart';

part 'questionnaire_answers_model.freezed.dart';
part 'questionnaire_answers_model.g.dart';

@freezed
class QuestionnaireAnswers with _$QuestionnaireAnswers {
  const factory QuestionnaireAnswers({
    required Map<String, String> answers,
    required String version,
    @JsonKey(
      fromJson: _timestampFromJson,
      toJson: _timestampToJson,
    )
    required DateTime completedAt,
  }) = _QuestionnaireAnswers;

  factory QuestionnaireAnswers.fromJson(Map<String, dynamic> json) => 
      _$QuestionnaireAnswersFromJson(json);
      
  factory QuestionnaireAnswers.create({
    required Map<int, String> answers, // Input keys: 0,1,2,3 (pages for Q_ID 1,2,3,4), 4 (page for Consumption Level), 5,6,.. (pages for Q_ID 6,7,..), 100,101...
    String version = '1.0',
  }) {
    final Map<String, String> formattedAnswers = {};
    
    answers.forEach((key, value) {
      if (key == 4) { // This is the 0-indexed page for the consumption summary question, which we want as 'q5'
        formattedAnswers['q5'] = value;
      } else if (key < 100) { // Process other standard questions (keys are 0-indexed page numbers)
        // Map the page index 'key' to the actual QuestionModel.id
        int questionModelIndex = -1;
        if (key >= 0 && key <= 3) { // Page indices 0, 1, 2, 3 correspond to QuestionModel indices 0, 1, 2, 3
          questionModelIndex = key;
        } else if (key > 4 && key < (QuestionnaireData.questions.length + 1 + 1)) { 
          // Page indices 5, 6, ... correspond to QuestionModel indices 4, 5, ... 
          // (because page 4 was consumption summary)
          // QuestionnaireData.questions has 12 items (indices 0-11). ID 13 is at index 11.
          // Page for ID 13 (index 11) is page key 12.
          // So, if key is 5, modelIndex = 4. If key is 12, modelIndex = 11.
          questionModelIndex = key - 1;
        }

        if (questionModelIndex != -1 && questionModelIndex < QuestionnaireData.questions.length) {
          final questionId = QuestionnaireData.questions[questionModelIndex].id;
          formattedAnswers['q$questionId'] = value;
        }
      }
      // Keys 100 and above are ignored for this specific Firestore document
    });
    
    return QuestionnaireAnswers(
      answers: formattedAnswers,
      version: version,
      completedAt: DateTime.now(),
    );
  }
}

// Helper methods for Timestamp conversion
Timestamp _timestampToJson(DateTime dateTime) => Timestamp.fromDate(dateTime);
DateTime _timestampFromJson(Timestamp timestamp) => timestamp.toDate(); 