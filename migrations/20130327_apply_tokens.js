/**
 * Applies backer tokens & items (this file will be updated periodically
 */

// mongo habitrpg ./node_modules/underscore/underscore.js migrations/20130327_apply_tokens.js

var mapping = [
    { // $1
        tokens: 0,
        users: []
    },
    { // $5
        tokens: 20,
        users: ['9']
    },
    { // $10
        tokens: 50,
        users: []
    },
    { // $15
        tokens: 100,
        users: []
    },
    { // $30
        tokens: 150,
        users: []
    },
    { // $45
        tokens: 170,
        users: []
    },
    { // $60
        tokens: 200,
        users: []
    },
    { // $70
        tokens: 240,
        users: []
    },
    { // $80
        tokens: 240,
        users: []
    },
    { // $90
        tokens: 280,
        users: []
    },
    { // $300
        tokens: 500,
        users: []
    },
    { // $800
        tokens: 500,
        users: []
    }
];

db.users.find().forEach(function(user){

    _.each(mapping, function(tier){
        if(
            (!user.backer || !user.backer.tokensApplied) &&

                (
                    _.contains(tier.users, user._id) ||
                        !!user.local && (
                            _.contains(tier.users, user.local.username) ||
                                _.contains(tier.users, user.local.email)
                            )
                    )
            ) {
            try {
                db.users.update(
                    {_id:user._id},
                    {
                        $set: { 'backer.tokensApplied': true, 'flags.ads': 'hide' },
                        $inc: { balance: (tier.tokens/4) }
                    }
                );
            } catch(e) {
                print(e);
            }
        }
    })

})

// This doesn't work, but shows the idea we're after better than the above
/*
_.each(mapping, function(tier){
    db.users.update(
        {
            $or: [
                { _id: { $in: tier.users } },
                { 'auth.local.username': { $in: tier.users } },
                { 'auth.local.email': { $in: tier.users } }
            ],
            'backer.tokensApplied': { $exists: false }
        },

        {
            $set: { 'backer.tokensApplied': true, 'flags.ads': 'hide' },
            $inc: { balance: (tier.tokens/4) }
        },

        { multi: true}
    )
})
*/
