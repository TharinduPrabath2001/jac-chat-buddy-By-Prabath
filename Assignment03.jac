import:py streamlit as st;

import:py from jaclang.core.llms, Anthropic;

glob llm = Anthropic();

glob messages = [];

enum PR_states {
    init_PR = 'initial run',
    chat_create = 'create chat graph',
    chat = 'chat with user'
}
glob state = PR_states.init_PR;

'''
This is the session node which carries data about the session.
'''
node session {}

'''
This walker is the chat walker through the graph.
'''
walker chat {
    can run with session entry{
        print("Hello World.....!!");
        if prompt := st.chat_input("What is up?") {
            messages.append({"role": "user", "content": prompt});
        with st.chat_message("user"){
            st.markdown(prompt);
            }
        # Generating and writing the response
        with st.chat_message("assistant"){
            response = self.answer_query(messages=[
                {"role": m["role"], "content": m["content"]}
                for m in messages
                ]);
            stream = st.write(response);
            }
        # Managing chat history
        messages.append({"role": "assistant", "content": response});
        }
        
        }
    can 'Continue the chat in a conversational mannor.'
answer_query(messages: 'chat history including the newest message' : list[dict[str, str]]) -> 'response to the final query':str
    by llm(temperature=0.7, max_tokens=1024);
}

'''
This ability will be called by running streamlit run app.py
'''
can main() {
    :g: state;
    st.title("Jac${Care}$");
    with st.sidebar {
        if st.button('Turn Off'){
        messages.clear();
    }
    }
    
    for message in messages{
        with st.chat_message(message["role"]){
            st.markdown(message["content"]);
        }
    }
       
    if state == PR_states.init_PR {
        end = root;
        end ++> session();
        state = PR_states.chat_create;
        print('Graph created');
        
        prompt = st.chat_input("What is up?");
    } elif state == PR_states.chat_create {
        chat() spawn [root -->](`?session)[0];
        print('Chatting with user');
    } elif state == PR_states.chat {
        print('New Session');
        
    }
    
    
}

