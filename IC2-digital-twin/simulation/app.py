import streamlit as st
import pandas as pd
import uuid
from simulator_runner import run_simulation, plot_results, plot_intervals, plot_probability_full
from llm_client import interpret_user_message

st.set_page_config(
    page_title="IC2 Parking Behavior Simulator",
    layout="wide"
)

# ==============================================================
# TITLE
# ==============================================================

st.markdown("<h1 style='text-align:center;'>🚗 IC2 Parking Behavior Simulator</h1>", 
            unsafe_allow_html=True)
st.write("")

# ==============================================================
# MODE SWITCH BUTTON
# ==============================================================

if "mode" not in st.session_state:
    st.session_state.mode = "manual"

if "current_params" not in st.session_state:
    st.session_state.current_params = {
        "num_simulations": 1000,
        "spots": 16,
        "percent_arrivals": 0.0,
        "percent_dwell_time": 0.0,
        "modify_from": None,
        "modify_to": None,
        "prediction_interval_value": 90,
        "warm_up_days": 1
    }

switch_col = st.columns([4, 2, 4])[1]  # center button

with switch_col:
    if st.session_state.mode == "manual":
        if st.button("🔄 Switch to LLM Chat", use_container_width=True):
            st.session_state.mode = "chat"
            st.rerun()
    else:
        if st.button("🔧 Switch to Manual Mode", use_container_width=True):
            st.session_state.mode = "manual"
            st.rerun()

st.write("")

# ==============================================================
# MANUAL SIMULATION MODE (FULL SCREEN)
# ==============================================================

if st.session_state.mode == "manual":

    st.markdown("<h2 style='text-align:center;'>⚙️ Manual Simulation</h2>", unsafe_allow_html=True)
    st.write("")

    # Create centered layout
    col = st.columns([1, 2, 1])[1]

    with col:
        st.subheader("Base Configuration")
        spots = st.number_input("Number of spots", 1, 32, 16)
        num_simulations = st.number_input("Number of simulations", 1, 10000, 1000)

        st.subheader("Modifications")
        percent_arrivals = st.number_input("Percent arrivals", -1.0, 2.0, 0.0)
        percent_dwell = st.number_input("Percent dwell time", -1.0, 2.0, 0.0)

        apply_time_window = st.checkbox("Apply modifications only in time range", value=False)

        if apply_time_window:
            modify_from = st.time_input("Modify from (HH:MM)")
            modify_to = st.time_input("Modify to (HH:MM)")
            modify_from_str = modify_from.strftime("%H:%M")
            modify_to_str = modify_to.strftime("%H:%M")
        else:
            modify_from_str = None
            modify_to_str = None

        st.subheader("Intervals Configuration")
        prediction_interval_value = st.number_input(
            "Prediction Interval (%)",
            min_value=50,
            max_value=99,
            value=90,
            step=1,
            help="Used to compute prediction intervals (p_low / p_high)"
        )
        
        st.write("")

        run_button = st.button("▶️ Run Simulation", use_container_width=True)

        if run_button:
            output_path = f"/tmp/sim_{uuid.uuid4().hex}.csv"

            # Add loading animation
            with st.spinner("Running simulation..."):
                df = run_simulation(
                    input_arrival_file="./data/arrival_per_5min_bin.csv",
                    input_dwell_file="./data/dwell_per_5min_bin.csv",
                    bin_size=5,
                    num_simulations=num_simulations,
                    spots=spots,
                    warm_up_days=1,
                    output_file=output_path,
                    percent_arrivals=percent_arrivals,
                    percent_dwell=percent_dwell,
                    modify_from=modify_from_str,
                    modify_to=modify_to_str
                )

            st.success("Simulation Completed!")

            fig = plot_results(df, "./data/occupied_mean_spots_5min.csv")
            st.pyplot(fig)

            st.download_button(
                "Download CSV",
                df.to_csv(index=False),
                file_name="simulation_results.csv",
                mime="text/csv",
                use_container_width=True
            )

            # Save figure to file
            import tempfile
            img_temp = tempfile.NamedTemporaryFile(delete=False, suffix=".png")
            fig.savefig(img_temp.name)

            # Add download button for PNG ---
            st.download_button(
                "Download Plot Image",
                data=open(img_temp.name, "rb").read(),
                file_name="simulation_plot.png",
                mime="image/png",
                use_container_width=True
            )

            fig2 = plot_intervals(df, prediction_interval_value)
            st.pyplot(fig2)

            # Save figure to file
            import tempfile
            img_temp2 = tempfile.NamedTemporaryFile(delete=False, suffix=".png")
            fig2.savefig(img_temp.name)

            # Add download button for PNG ---
            st.download_button(
                "Download Intervals Plot",
                data=open(img_temp2.name, "rb").read(),
                file_name="intervals_plot.png",
                mime="image/png",
                use_container_width=True
            )

            # ================================
            # Probability of Full Plot
            # ================================
            st.subheader("📊 Probability of Parking Being FULL")

            fig3, df_prob = plot_probability_full(df, spots)
            st.pyplot(fig3)

            # Download figure
            import io
            img_buf = io.BytesIO()
            fig3.savefig(img_buf, format="png")
            img_buf.seek(0)

            st.download_button(
                label="Download Probability FULL Plot",
                data=img_buf,
                file_name="probability_full.png",
                mime="image/png"
            )

            # Download table
            st.download_button(
                label="Download Probability FULL CSV",
                data=df_prob.to_csv(index=False),
                file_name="probability_full.csv",
                mime="text/csv"
            )

            

# ==============================================================
# LLM CHAT MODE (FULL SCREEN)
# ==============================================================

else:

    st.markdown("<h2 style='text-align:center;'>💬 Chat with the Simulator</h2>", unsafe_allow_html=True)
    st.write("")

    # Centering the chat block
    col = st.columns([1, 2, 1])[1]

    with col:

        if "messages" not in st.session_state:
            st.session_state.messages = []

        for msg in st.session_state.messages:
            role = "assistant" if msg["role"] == "assistant" else "user"
            with st.chat_message(role):
                st.write(msg["text"])

        user_input = st.chat_input("Ask something like: 'What if arrivals increase 20% between 14:00 and 17:00 with 14 spots? Or increase simulations to 10000.'")

        if user_input:
            st.session_state.messages.append({"role": "user", "text": user_input})

            # -------------------------
            # Interpret message via LLM helper
            # -------------------------
            # pass conversation history if you want the remote model to see it
            history = [m for m in st.session_state.messages]
            parsed = interpret_user_message(user_input, history=history)  # ####

            if parsed == {}:
                st.session_state.current_params = {
                    "num_simulations": 1000,
                    "spots": 16,
                    "percent_arrivals": 0.0,
                    "percent_dwell_time": 0.0,
                    "modify_from": None,
                    "modify_to": None,
                    "prediction_interval_value": 90,
                    "warm_up_days": 1
                }
                # Create assistant message
                reset_msg = "✔️ Reset to default simulation parameters."
                st.session_state.messages.append({"role": "assistant", "text": reset_msg})
                with st.chat_message("assistant"):
                    st.write(reset_msg)


            # Merge parsed partial json into current_params (remember previous steps)
            cp = st.session_state.current_params
            # fields we accept and mapping from possible keys to internal names
            key_map = {
                "num_simulations": "num_simulations",
                "simulations": "num_simulations",
                "spots": "spots",
                "percent_arrivals": "percent_arrivals",
                "arrivals": "percent_arrivals",
                "percent_dwell_time": "percent_dwell_time",
                "dwell": "percent_dwell_time",
                "modify_from": "modify_from",
                "from": "modify_from",
                "modify_to": "modify_to",
                "to": "modify_to",
                "prediction_interval_value": "prediction_interval_value",
                "warm_up_days": "warm_up_days"
            }

            # Apply parsed values (only those present)
            for k, v in parsed.items():
                lk = k.lower()
                if lk in key_map:
                    target = key_map[lk]
                    # normalize percent values: if parsed value is numeric and appears as percent (like 20) convert to fraction
                    if target in ("percent_arrivals", "percent_dwell_time"):
                        # if value looks like 0.2 already, keep; if >1 assume percent number -> convert to fraction
                        try:
                            f = float(v)
                            if abs(f) > 1.0:
                                f = f / 100.0
                            # For dwell decreases user may say "-10%" -> keep sign
                            cp[target] = f
                        except Exception:
                            # if it's a string like "decrease 10%" try to extract number
                            m = None
                            try:
                                import re
                                mm = re.search(r"-?\d+(\.\d+)?", str(v))
                                if mm:
                                    f = float(mm.group(0))
                                    if abs(f) > 1.0:
                                        f = f / 100.0
                                    cp[target] = f
                            except Exception:
                                pass
                    elif target in ("num_simulations", "spots", "prediction_interval_value", "warm_up_days"):
                        try:
                            cp[target] = int(v)
                        except Exception:
                            try:
                                cp[target] = int(float(v))
                            except Exception:
                                pass
                    elif target in ("modify_from", "modify_to"):
                        # expect HH:MM
                        s = str(v)
                        # accept times like "14", "14:00", "2pm" -> minimal normalization
                        if ":" in s:
                            cp[target] = s
                        else:
                            # try to parse integers like 14 -> 14:00
                            try:
                                h = int(s)
                                cp[target] = f"{h:02d}:00"
                            except Exception:
                                cp[target] = s
                    else:
                        cp[target] = v

            # Save back
            st.session_state.current_params = cp

            required_fields = [
                "num_simulations", "spots",
                "percent_arrivals", "percent_dwell_time",
                "modify_from", "modify_to"
            ]

            for field in required_fields:
                if field not in cp:
                    st.error(f"Missing required parameter: {field}")
                    st.stop()

            # Build a short assistant summary message
            summary_lines = []
            summary_lines.append("Interpreted simulation parameters (merged with previous state):")
            for k, v in cp.items():
                summary_lines.append(f"- {k}: {v}")

            assistant_text = "\n".join(summary_lines)
            st.session_state.messages.append({"role": "assistant", "text": assistant_text})
            with st.chat_message("assistant"):
                st.write(assistant_text)

            # Optionally **run** the simulation immediately (do so by default)
            run_now = True  # could be replaced by a checkbox UI if you want
            if run_now:
                output_path = f"/tmp/sim_{uuid.uuid4().hex}.csv"
                with st.spinner("Running simulation with interpreted parameters..."):
                    # call run_simulation with the merged params
                    try:
                        df = run_simulation(
                            input_arrival_file="./data/arrival_per_5min_bin.csv",
                            input_dwell_file="./data/dwell_per_5min_bin.csv",
                            bin_size=5,
                            num_simulations=st.session_state.current_params["num_simulations"],
                            spots=st.session_state.current_params["spots"],
                            warm_up_days=st.session_state.current_params.get("warm_up_days", 1),
                            output_file=output_path,
                            percent_arrivals=st.session_state.current_params["percent_arrivals"],
                            percent_dwell=st.session_state.current_params["percent_dwell_time"],
                            modify_from=st.session_state.current_params["modify_from"],
                            modify_to=st.session_state.current_params["modify_to"]
                        )

                        st.success("Simulation Completed!")

                        fig = plot_results(df, "./data/occupied_mean_spots_5min.csv")
                        st.pyplot(fig)

                        st.download_button(
                            "Download CSV",
                            df.to_csv(index=False),
                            file_name="simulation_results.csv",
                            mime="text/csv",
                            use_container_width=True
                        )

                        # show intervals plot using stored prediction interval setting
                        fig2 = plot_intervals(df, st.session_state.current_params.get("prediction_interval_value", 90))
                        st.pyplot(fig2)

                        st.subheader("📊 Probability of Parking Being FULL")
                        fig3, df_prob = plot_probability_full(df, st.session_state.current_params["spots"])
                        st.pyplot(fig3)

                    except Exception as e:
                        st.error(f"Simulation failed: {e}")
