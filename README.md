# README #

## General Concept

The 'Construction Builder' app is based on the idea that a fast way to become fluent when learning a language is by mastering a plethora of constructions. A construction is essentially a fill in the blank sentence (i.e. 'The ____ is on the ____.'). By swapping out the blanks with as much of your known vocabulary in the language as possible, you become familiar not only with the words themselves but quickly form useful sentences with them. You not only remember words, but you know when and how to use them.

There are many beautiful languages in the world for which there is little or inadequate material for learning. This is meant to be a language agnostic tool. Equipped with this tool and an editor who speaks the language well or natively, a learner can build their own material. the process itself will help acquisition of the language...

## The Setup

The app is being built to enable a learner to maintain a list of vocabulary and a list of constructions. Words from the vocabulary list will be randomly inserted into a particular construction based on grammatical characteristics ('markers') that identify the words. The new variation on the construction can then be approved as legitimate sentences by the learner or an editor. The learner can then add the variation permanently to a list of approved variations on that construction. Recordings of the variations will be able to be stored for reference; preferably, a native speaking or fluent editor makes them.

Regretably, only the vocab list portion of the application is currently built out. As the foundation of the entire app, it's functionality is quite impactful and varied. Using the vocab list and word features themselves are useful for learning.

### The Vocab List

A learner can create an account and be the owner of a new vocab list that is assigned to him when he signs up. When signed in, a personal list appears below the sample list on the **home** page. Clicking on the name of the list allows the user to see it's words.

A new list starts out empty viewing a vocab list presents an option to add a new word. An editor or the owner of the list (the learner) can add words.

### Individual Words

#### Adding a New Word

When choosing the option to add a new word, a form to do so appears. An input field to enter the word itself is displayed. It would likely be best to enter the form of the word that would appear in a dictionary search at this point; other forms of the word can be associated with it later. The second input field is to describe the type of the word: adjective, noun, verb, adverb. **Note**, other possible word types may be added in the future, or the ability for a learner to add additional types.

Filling in the form fields and pressing 'Add New Word', the word is added to the vocab list if signed in as the list owner (learner) and added to a queue that the owner can approve if signed in as an editor.

#### Viewing an Individual Word

By clicking on an individual word while viewing a vocab list, the user can see more details about the word. A translation of the word can be optionally displayed. The current forms associated with the word are listed as well as the grammatical markers associated with them (i.e. first person, singular, etc.)

#### Flash Card Learning
##### with Vocabulary Words

Viewing one word at a time without displaying the translation allows a learner to take advantage of recalling the translation of the word. Clicking the option to show the translation verifies the learners recall or reminds the learner of a meaning they forgot. Clicking **Next Word** brings the user to the next word in the list. To go back to any point in the list, a user can click **Back to list**. 

#### Forms of the Word

The foundation of the 'constructions' will be the various forms associated with a given word. The **word type** and the **markers** will be consulted to fill in the blank of a constructional phrase.

An example 'form' of the word *run* is *runs*. It is in the 'third person singular'. Markers **third_person** and **singular** should be applied. Some words can have multiple markers as the same form is used in many grammatical scenarios. The word *ran* for example could have markers: **past_tense, first_person, second_person, third_person, singular, plural**. It would only be considered to operate in the 'third person singular' in the 'past tense' sentence "He ran.".

An extensive knowlede of grammar is not necessary, however. Not including markers would simply limit the algorithm for randomly inserting word forms into constructions. The opportunity to automatically use the form in sentences could be restricted. Yet, a form could still be manually inserted into a construction.

Learning basic grammar in one's native language helps acquire a new language. Learning a language after early childhood is usually presented with learning tools that rely somewhat on knowledge gained when a person is school age. Many questions about how a language works are easily answered if posed with some understanding of the foundational grammar of one's own native language. Learning the grammatical meaning of the **markers** presented or ones that a learner or editor makes can quicken the learning process.

Optionally, having an editor that understands grammar (of either language) better than the learner can increase the functionality of the app if the learner is not grammatically inclined.

#### Adding a Form of a Word

When viewing the forms of a word, an option is presented to **Add a Word Form**. Clicking the option presents a form to fill in fields for the 'form' and the 'markers'. Fill in the new form of the word in the associated field. In the field for the markers, list the markers in any order separated by a comma: 'plural, feminine, third_person'.

A list of approved markers appears and can be used as a guide. **Note** Adding new markers for the given list will be added in the future. Since grammar changes per language, a language may require grammar elements that do not exist in another language. For example, Russian uses an extensive case system which does not apply to many other languages like English where there are only remnants of a case system. Adding varied markers per vocab list will allow this to be a language agnostic tool.

The underscore is an important character to include if a marker appears with one. Likewise any marker must be entered as it appears in the approved marker list so as to be applied. An entry that is not properly formatted will be excluded while the other properly formatted markers will apply. Example, for the input 'third person, first_person, second_person, singular' markers **first_person, second_person, singular** would be applied and the improperly formatted 'third person' would not.

#### Otherwise Modifying a Word
##### Deleting or Adding Words, Translations, Word Forms

When viewing an individual word, a learner (list owner) can click options to add new words, translations, or word forms. Actions of the list owner will be directly applied.

An editor who chooses to modify the vocab list or individual word will have their changes queued for approval by the list owner. 

A list owner can see the editors queued modifications when viewing the vocab list or when viewing the individual word if it's a change to the word itself (add or delete translation, or word form). An owner can add the changes or reject and thereby delete them. Either way, a list owner's action will remove the provisional change from the given queue.
